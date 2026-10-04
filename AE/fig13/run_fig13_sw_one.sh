#!/bin/bash
# Fig-13, Capybara-SW column, one measurement: N backends behind Capybara's software
# switch (capybara-switch, one core on node7), two open-loop caladan clients on
# node5/node6 sharing the offered load (same client form as Fig 10).
#   usage: run_fig13_sw_one.sh <N backends> <offered rps>  -> "RES sw <N> <rps> <achieved> p99=<us>"
# Needs fig13_sw_bringup.sh first (switch program, node7 freed for the switch).
set -u
N=$1; RPS=$2
SW=${SWTREE:-/homes/inho/Capybara/capybara-fig13sw}   # paper-era tree (4599b186) rebuilt with the capybara-switch feature; see patches/
BE=${BETREE:-/homes/inho/Capybara/capybara-fig13be}   # backend tree: the Fig 10 server without reply rewriting (the switch rewrites)
CL=/homes/inho/Capybara/caladan-fig8
RT=${RT:-5}; CONNS=${CONNS:-240}                       # connections per client (12 groups of 20, as in Fig 10)
VIP=10.0.1.7:10000
ENVC="MTU=1500 MSS=1500 NUM_CORES=4 LIBOS=catnip DATA_SIZE=${DATA_SIZE:-256} LD_LIBRARY_PATH=\\/homes/inho/lib:\\/homes/inho/lib/x86_64-linux-gnu"

# 1) fresh switch, backends and dpdk-ctrl primaries (as in Fig 10/15: a backend that
#    exits under overload keeps part of the primary's packet-buffer pool, so the pool is
#    recreated for every measurement). A backend is stopped with SIGINT and given time
#    to dump its time log before anything is killed.
fresh_node(){ ssh node$1 "sudo pkill -INT -x http-server.elf 2>/dev/null; for i in \$(seq 1 25); do pgrep -x http-server.elf >/dev/null || break; sleep 1; done; sudo pkill -9 -x http-server.elf 2>/dev/null; sudo pkill -x dpdk-ctrl.elf 2>/dev/null; for s in dc$1 hs0 hs1 hs2 hs3; do tmux kill-session -t \$s 2>/dev/null; done; sleep 1; sudo rm -rf /var/run/dpdk/rte 2>/dev/null; sudo rm -f /tmp/ae-dc$1.log; tmux new-session -d -s dc$1 \"cd $BE && timeout 7200 make PREFIX=/homes/inho dpdk-ctrl-node$1 > /tmp/ae-dc$1.log 2>&1\"" >/dev/null 2>&1; }
for M in 8 9 10; do fresh_node $M & done; wait
sleep 14
for M in 8 9 10; do ssh node$M "pgrep -x dpdk-ctrl.elf >/dev/null" 2>/dev/null || { echo "RES sw $N $RPS DPDK_CTRL_DOWN_node$M p99=NA"; exit 1; }; done
tmux kill-session -t sw7 2>/dev/null; sudo pkill -INT -x capybara-switch 2>/dev/null; sleep 1; sudo pkill -x capybara-switch 2>/dev/null
sudo rm -rf /var/run/dpdk/rte 2>/dev/null; rm -f /tmp/ae-f13sw.log
# 2) the software switch on node7: round-robins new connections over the first N entries
#    of its backend table (entry j -> node 8 + j%3, port 10000 + j/3)
tmux new-session -d -s sw7 "cd $SW && sudo -E env $ENVC NUM_CORES=1 NUM_BACKENDS=$N CONFIG_PATH=$SW/scripts/config/node7_config.yaml numactl -m0 taskset --cpu-list 1 $SW/bin/examples/rust/capybara-switch-ae.elf $VIP 10.0.1.7:10001 > /tmp/ae-f13sw.log 2>&1"
# 3) N backends, same mapping, attached to their node's dpdk-ctrl (core 1-4)
for j in $(seq 0 $((N-1))); do M=$((8 + j % 3)); P=$((10000 + j / 3)); C=$((j / 3 + 1))
  ssh node$M "tmux new-session -d -s hs$((j/3)) \"cd $BE && sudo -E env CORE_ID=$C CONFIG_PATH=$BE/scripts/config/node${M}_config.yaml $ENVC numactl -m0 $BE/bin/examples/rust/http-server.elf 10.0.1.$M:$P $VIP > /tmp/ae-f13be$j.log 2>&1\"" >/dev/null 2>&1
done
sleep 7
pgrep -x capybara-switch >/dev/null || { echo "RES sw $N $RPS SW_SWITCH_FAIL p99=NA"; exit 1; }
UP=0; for M in 8 9 10; do c=$(ssh node$M "pgrep -c -x http-server.elf" 2>/dev/null); UP=$((UP + ${c:-0})); done
[ "$UP" = "$N" ] || { echo "RES sw $N $RPS BACKENDS=$UP/$N p99=NA"; exit 1; }
# 4) fresh client iokernels (as Fig 10 does per measurement: a runtime that aborted on
#    an overloaded rung can leave the iokernel wedged for the next attach)
for n in 5 6; do bash ~/capybara-AE-runs/restart_client_iokernel.sh $n /homes/inho/Capybara/caladan-fig8-n6 >/dev/null 2>&1 & done; wait
# 5) two open-loop clients (node5, node6), half the load each, in the Fig 10 client form
#    (per-connection schedules over 240 connections, zipf 1.2 across connections; a
#    plain --pps schedule on these nodes skips ~12% of its sends as "late")
HALF=$((RPS / 2))
SPEC=$(python3 ~/capybara-AE-runs/fig10/gen_spec.py uniform $HALF $RT)
CMD="--mode runtime-client --protocol=http --transport=tcp --samples=1 --pps=10 --threads=$CONNS --runtime=$RT --discard_pct=0 --output=buckets --rampup=0 --zipf=1.2 --loadshift=$SPEC --exptid=/tmp/ae-f13x"
for n in 5 6; do
  ssh node$n "tmux kill-session -t cl$n 2>/dev/null; sudo pkill -x synthetic 2>/dev/null; sudo rm -f /tmp/ae-f13.log /tmp/ae-f13x.latency /tmp/ae-f13x.latency_raw; tmux new-session -d -s cl$n \"cd $CL && sudo timeout $((RT + 60)) env LD_LIBRARY_PATH=\\/homes/inho/lib numactl -m0 apps/synthetic/target-fig10/release/synthetic $VIP --config client_node$n.config $CMD > /tmp/ae-f13.log 2>&1; echo CLIENT_EXIT=\\\$? >> /tmp/ae-f13.log\"" >/dev/null 2>&1
done
# 6) collect: completed requests (histogram sums) / runtime; p99 = the worse client
ACH=0; P99=0
for n in 5 6; do
  for i in $(seq 1 $((RT + 60))); do ssh node$n "grep -aq CLIENT_EXIT /tmp/ae-f13.log 2>/dev/null" && break; sleep 1; done
  c=$(ssh node$n "awk -F, '{s+=\$2} END {print s+0}' /tmp/ae-f13x.latency 2>/dev/null"); ACH=$((ACH + ${c:-0}))
  p=$(ssh node$n "strings /tmp/ae-f13.log 2>/dev/null | grep -oE '99th \(us\): [0-9]+' | grep -oE '[0-9]+\$' | tail -1"); [ ${#p} -le 8 ] && [ "${p:-0}" -gt "$P99" ] && P99=$p
done
ACH=$((ACH / RT))
[ "$ACH" -gt 0 ] || P99=NA
echo "RES sw $N $RPS $ACH p99=$P99"
