#!/bin/bash
# Fig-10 single measurement: 12 backends, 720 conns via 3 clients (node5/6/7).
# usage: run_fig10_one.sh <LWRR|CAPY|UNI> <size_bytes> <total_rps>
# Prints: RES <cond> <size> <target_rps> <achieved_rps> <gbps>
COND=$1; SZ=$2; RPS=$3
D=~/capybara-AE-runs/fig10
RUNTIME=${RT:-3}
PERCLIENT=$((RPS/3))
if [ "$COND" = "CAPY" ]; then
  MR=100000; DIST=${DIST_OVERRIDE:-conn_zipf}
  POLICY="SIGNAL_POLICY_MIGS=1 FAIR_SHARE_N=12 MIG_INDIVIDUAL_FLOOR=${FLOOR:-100} MIG_CONN_RPS_CAP=${CAP:-50} MIG_COOLDOWN_MS=${MCD:-10}"
elif [ "$COND" = "LWRR" ]; then
  MR=0; DIST=${DIST_OVERRIDE:-conn_zipf}; POLICY="SIGNAL_POLICY_MIGS=0"
elif [ "$COND" = "SOLO" ]; then
  MR=0; DIST=${SPREAD:-solo}; POLICY="SIGNAL_POLICY_MIGS=0"
elif [ "$COND" = "UNIP" ]; then
  MR=100000; DIST=uniform
  POLICY="SIGNAL_POLICY_MIGS=1 FAIR_SHARE_N=12 MIG_INDIVIDUAL_FLOOR=${FLOOR:-100} MIG_CONN_RPS_CAP=${CAP:-50} MIG_COOLDOWN_MS=${MCD:-10}"
else
  MR=0; DIST=uniform; POLICY="SIGNAL_POLICY_MIGS=0"
fi
LS=$(python3 $D/gen_spec.py $DIST $PERCLIENT $RUNTIME)

# 1) fresh servers (12 instances, fig7 pattern) + dpdk-ctrl for CAPY
for N in 8 9 10; do ssh node$N "sudo pkill -x http-server.elf 2>/dev/null; for p in 0 1 2 3; do tmux kill-session -t hs\$p 2>/dev/null; done; true" >/dev/null 2>&1 & done; wait
sleep 1
for N in 8 9 10; do ssh node$N "sudo pkill -x dpdk-ctrl.elf 2>/dev/null; tmux kill-session -t dc$N 2>/dev/null; sudo rm -rf /var/run/dpdk/rte 2>/dev/null; true" >/dev/null 2>&1 & done; wait
sleep 1
for N in 8 9 10; do ssh node$N "tmux new-session -d -s dc$N \"cd /homes/inho/Capybara/capybara-fig10 && MTU=9216 timeout 1200 make PREFIX=/homes/inho dpdk-ctrl-node$N > /tmp/ae-dc$N.log 2>&1\"" >/dev/null 2>&1 & done; wait
sleep 14
for N in 8 9 10; do
  ssh node$N "cd /homes/inho/Capybara/capybara-fig10; for p in 0 1 2 3; do c=\$((p+1)); tmux new-session -d -s hs\$p \"cd /homes/inho/Capybara/capybara-fig10 && sudo -E env LOG_EVERY_RPS_SIGNAL=0 $POLICY MAX_REACTIVE_MIGS=$MR MAX_PROACTIVE_MIGS=0 RECV_QUEUE_LEN_THRESHOLD=1000000 MIG_DELAY=0 MIG_PER_N=10 CONFIGURED_STATE_SIZE=0 MIN_THRESHOLD=1000000 RPS_THRESHOLD=0.3 THRESHOLD_EPSILON=0.1 CORE_ID=\$c CONFIG_PATH=scripts/config/node${N}_config.yaml MTU=${SMTU:-9000} MSS=${SMSS:-8960} NUM_CORES=4 USE_JUMBO=1 LIBOS=catnip DATA_SIZE=$SZ LD_LIBRARY_PATH=\\/homes/inho/lib:\\/homes/inho/lib/x86_64-linux-gnu timeout 900 numactl -m0 bin/examples/rust/http-server.elf 10.0.1.${N}:1000\$p >/tmp/ae-hs${N}_\$p.log 2>&1\"; sleep 2; done" >/dev/null 2>&1 &
done
wait
FLEET=0
for i in $(seq 1 12); do
  FLEET=$(for N in 8 9 10; do ssh node$N "pgrep -c http-server.el" 2>/dev/null; done | paste -sd+ | bc)
  [ "$FLEET" = "12" ] && break; sleep 1
done
if [ "$FLEET" != "12" ]; then echo "RES $COND $SZ $RPS FLEET_FAIL 0"; exit 1; fi

# 2) clients on node5/6/7 (240 conns each, per-server loadshift groups)
# fresh iokernel on node5/6 for every measurement (see restart_client_iokernel.sh)
bash ~/capybara-AE-runs/restart_client_iokernel.sh 5 /homes/inho/Capybara/caladan-fig8-n6 || { echo "RES $COND $SZ $RPS IOK5_FAIL 0"; exit 1; }
bash ~/capybara-AE-runs/restart_client_iokernel.sh 6 /homes/inho/Capybara/caladan-fig8-n6 || { echo "RES $COND $SZ $RPS IOK6_FAIL 0"; exit 1; }
CMD="--mode runtime-client --protocol=http --transport=tcp --samples=1 --pps=10 --threads=240 --runtime=$RUNTIME --discard_pct=0 --output=buckets --rampup=0 --zipf=1.2 --loadshift=$LS --exptid=/tmp/ae-f10x"
ssh node5 "tmux kill-session -t cl5 2>/dev/null; sudo pkill -x synthetic 2>/dev/null; sudo rm -f /tmp/ae-f10.log /tmp/ae-f10x.latency /tmp/ae-f10x.latency_raw; tmux new-session -d -s cl5 \"cd /homes/inho/Capybara/caladan-fig8 && sudo timeout 300 env LD_LIBRARY_PATH=\\/homes/inho/lib numactl -m0 apps/synthetic/target-fig10/release/synthetic 10.0.1.8:55555 --config client_node5.config $CMD > /tmp/ae-f10.log 2>&1\"" >/dev/null 2>&1
ssh node6 "tmux kill-session -t cl6 2>/dev/null; sudo pkill -x synthetic 2>/dev/null; sudo rm -f /tmp/ae-f10.log /tmp/ae-f10x.latency /tmp/ae-f10x.latency_raw; tmux new-session -d -s cl6 \"cd /homes/inho/Capybara/caladan-fig8 && sudo timeout 300 numactl -m0 apps/synthetic/target-fig10/release/synthetic 10.0.1.8:55555 --config client_node6.config $CMD > /tmp/ae-f10.log 2>&1\"" >/dev/null 2>&1
tmux kill-session -t cl7 2>/dev/null; sudo pkill -x synthetic 2>/dev/null; sudo rm -f /tmp/ae-f10.log /tmp/ae-f10x.latency /tmp/ae-f10x.latency_raw
tmux new-session -d -s cl7 "cd /homes/inho/Capybara/caladan-fig8 && sudo timeout 300 numactl --preferred=0 apps/synthetic/target-fig10/release/synthetic 10.0.1.8:55555 --config client_node7.config $CMD > /tmp/ae-f10.log 2>&1"

# 3) wait all three clients to finish
for i in $(seq 1 60); do
  A=$(pgrep -x synthetic >/dev/null && echo 1 || echo 0)
  B=$(ssh node5 "pgrep -x synthetic >/dev/null && echo 1 || echo 0" 2>/dev/null)
  C=$(ssh node6 "pgrep -x synthetic >/dev/null && echo 1 || echo 0" 2>/dev/null)
  [ "$A$B$C" = "000" ] && break
  sleep 2
done
sleep 2

# 4) collect: client-side completed requests (histogram sums) -> goodput
CL7=$(awk -F, "{s+=\$2} END {print s+0}" /tmp/ae-f10x.latency 2>/dev/null)
CL6=$(ssh node6 "awk -F, \"{s+=\\\$2} END {print s+0}\" /tmp/ae-f10x.latency 2>/dev/null")
CL5=$(ssh node5 "awk -F, \"{s+=\\\$2} END {print s+0}\" /tmp/ae-f10x.latency 2>/dev/null")
OK=1; [ -z "$CL7" ] || [ -z "$CL6" ] && OK=0
read ACH GBPS <<< $(python3 -c "
r = (${CL7:-0} + ${CL6:-0} + ${CL5:-0}) / $RUNTIME
print(int(r), f'{r*$SZ*8/1e9:.2f}')")
for N in 8 9 10; do ssh node$N "sudo pkill -x http-server.elf 2>/dev/null; true" >/dev/null 2>&1 & done; wait
P99=$(strings /tmp/ae-f10.log 2>/dev/null | grep -oE "99th \(us\): [0-9]+" | grep -oE "[0-9]+$" | tail -1)
echo "RES $COND $SZ $RPS $ACH $GBPS p99=${P99:-NA} ok=$OK n5=${CL5:-0} n6=${CL6:-0} n7=${CL7:-0}"
