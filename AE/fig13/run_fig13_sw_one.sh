#!/bin/bash
# Fig-13, Capybara-SW column, one measurement: N backends behind Capybara's software
# switch on node8 (the paper-era tree at 4599b186, the commit of the day the paper's
# runs were taken), one open-loop caladan client on node7 with 128 connections.
# usage: run_fig13_sw_one.sh <N backends> <offered rps>    -> "RES sw <N> <rps> <achieved> p99=<us>"
set -u
N=$1; RPS=$2
[ "$N" -le 8 ] || { echo "RES sw $N $RPS UNSUPPORTED(max 8 backends: node9+node10 x 4) p99=NA"; exit 1; }
T=${SWTREE:-/homes/inho/Capybara/capybara-fig13sw}      # paper-era tree (4599b186) rebuilt: capybara-switch.elf (+8-backend table) and http-server.elf (tcp-migration, capy-time-log)
CL=/homes/inho/Capybara/caladan-fig8
RT=${RT:-5}; CONNS=${CONNS:-128}
ENVC="MTU=1500 MSS=1500 NUM_CORES=4 LIBOS=catnip DATA_SIZE=${DATA_SIZE:-256} LD_LIBRARY_PATH=\\/homes/inho/lib:\\/homes/inho/lib/x86_64-linux-gnu"

# 1) fresh processes on the server nodes
for M in 8 9 10; do ssh node$M "sudo pkill -INT -x http-server.elf 2>/dev/null; sudo pkill -INT -f capybara-switch.elf 2>/dev/null; sleep 1; sudo pkill -x http-server.elf 2>/dev/null; sudo pkill -f capybara-switch.elf 2>/dev/null; sudo pkill -x dpdk-ctrl.elf 2>/dev/null; for s in sw8 dc9 dc10 hs0 hs1 hs2 hs3; do tmux kill-session -t \$s 2>/dev/null; done; sudo rm -rf /var/run/dpdk/rte 2>/dev/null; true" >/dev/null 2>&1 & done; wait
sleep 1
# 2) the software switch on node8 (DPDK primary on node8; node8's backends attach to it)
ssh node8 "tmux new-session -d -s sw8 \"cd $T && sudo -E env $ENVC NUM_CORES=1 NUM_BACKENDS=$N CONFIG_PATH=$T/scripts/config/node8_config.yaml numactl -m0 taskset --cpu-list 1 $T/bin/examples/rust/capybara-switch.elf 10.0.1.8:10000 10.0.1.8:10001 > /tmp/ae-f13sw.log 2>&1\"" >/dev/null 2>&1
# dpdk-ctrl primaries on node9 (and node10 when N > 4), as the 2024 driver did (be-dpdk-ctrl-node9)
ssh node9 "tmux new-session -d -s dc9 \"cd $T && timeout 1200 make PREFIX=/homes/inho be-dpdk-ctrl-node9 > /tmp/ae-dc9.log 2>&1\"" >/dev/null 2>&1
[ $N -gt 4 ] && ssh node10 "tmux new-session -d -s dc10 \"cd $T && sudo -E NUM_CORES=4 CORE_ID=5 CONFIG_PATH=$T/scripts/config/node10_config.yaml LD_LIBRARY_PATH=$T/lib:/homes/inho/lib/x86_64-linux-gnu taskset --cpu-list 4 timeout 1200 $T/bin/examples/rust/dpdk-ctrl.elf > /tmp/ae-dc10.log 2>&1\"" >/dev/null 2>&1
sleep 14
ssh node8 "pgrep -f capybara-switch.elf >/dev/null" || { echo "RES sw $N $RPS SW_SWITCH_FAIL p99=NA"; exit 1; }
# 3) N backends: j -> node 9 + j/4, port 10000 + j%4, core j%4+1 (the switch's backend table)
for j in $(seq 0 $((N-1))); do M=$((9 + j / 4)); P=$((10000 + j % 4)); C=$((j % 4 + 1))
  ssh node$M "tmux new-session -d -s hs$((j%4)) \"cd $T && sudo -E env CORE_ID=$C CONFIG_PATH=$T/scripts/config/node${M}_config.yaml $ENVC numactl -m0 $T/bin/examples/rust/http-server.elf 10.0.1.$M:$P 10.0.1.8:10000 > /tmp/ae-f13be$j.log 2>&1\"" >/dev/null 2>&1
  sleep 1
done
sleep 3
UP=0; for M in 9 10; do c=$(ssh node$M "pgrep -c http-server.el" 2>/dev/null); UP=$((UP + ${c:-0})); done
[ "$UP" = "$N" ] || { echo "RES sw $N $RPS BACKENDS=$UP/$N p99=NA"; exit 1; }
# 4) one open-loop client on node7 -> the software switch
tmux kill-session -t f13c 2>/dev/null; sudo pkill -x synthetic 2>/dev/null; rm -f /tmp/ae-f13.log /tmp/ae-f13x.latency /tmp/ae-f13x.latency_raw
tmux new-session -d -s f13c "cd $CL && sudo timeout $((RT + 40)) numactl -m0 apps/synthetic/target-fig10/release/synthetic 10.0.1.8:10000 --config client_node7.config --mode runtime-client --protocol=http --transport=tcp --samples=1 --pps=$RPS --threads=$CONNS --runtime=$RT --discard_pct=0 --output=buckets --rampup=0 --exptid=/tmp/ae-f13x > /tmp/ae-f13.log 2>&1; echo CLIENT_EXIT=\$? >> /tmp/ae-f13.log"
for i in $(seq 1 $((RT + 45))); do grep -aq CLIENT_EXIT /tmp/ae-f13.log 2>/dev/null && break; sleep 1; done
R=$(grep -a "\[RESULT\]" /tmp/ae-f13.log 2>/dev/null | tail -1 | sed 's/.*\[RESULT\] *//')
ACH=$(echo "$R" | awk -F', *' '{print $2+0}'); P99=$(echo "$R" | awk -F', *' '{print $7+0}')
if [ "${ACH:-0}" = 0 ] && [ -s /tmp/ae-f13x.latency ]; then ACH=$(awk -F, -v rt=$RT '{s+=$2} END {printf "%d", s/rt}' /tmp/ae-f13x.latency); fi
echo "RES sw $N $RPS ${ACH:-0} p99=${P99:-NA}"
