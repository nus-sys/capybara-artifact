#!/bin/bash
# Fig-7 AE single run (called by run_fig7.sh). usage: run_one.sh <LWRR|CAPY> <zipf|0> <runid>
#   LWRR: no migration, main client = node7 @1.8M pps, shortflow = node6 (threads=10)
#   CAPY: migration on,  main client = node6 @1.35M pps, shortflow = node7 (threads=1)
# Operating points are calibrated per condition (see README); override via LWRR_PPS/CAPY_PPS.
# Appends one result line to fig7_results.txt on success; exits 1 on failure (caller retries).
COND=$1; Z=$2; RID=$3
D=~/capybara-AE-runs/fig7
RES=$D/fig7_results.txt
if [ "$COND" = "CAPY" ]; then MR=20; PPS=${CAPY_PPS:-1350000}; else MR=0; PPS=${LWRR_PPS:-1800000}; fi

# 1) kill old server instances (parallel across nodes)
for N in 8 9 10; do ssh node$N "sudo pkill -x http-server.elf 2>/dev/null; for p in 0 1 2 3; do tmux kill-session -t hs\$p 2>/dev/null; done; true" >/dev/null 2>&1 & done; wait
sleep 1

# 2) CAPY only: fresh dpdk-ctrl (flushes stale rte_flow rules + RX rings — required for migration)
if [ "$COND" = "CAPY" ]; then
  for N in 8 9 10; do ssh node$N "sudo pkill -x dpdk-ctrl.elf 2>/dev/null; tmux kill-session -t dc$N 2>/dev/null; true" >/dev/null 2>&1 & done; wait
  sleep 1
  for N in 8 9 10; do ssh node$N "tmux new-session -d -s dc$N \"cd /homes/inho/Capybara/capybara && make PREFIX=/homes/inho dpdk-ctrl-node$N > /tmp/ae-dc$N.log 2>&1\"" >/dev/null 2>&1 & done; wait
  sleep 14
fi

# 3) start 12 server instances (nodes in parallel, 2s stagger within a node)
for N in 8 9 10; do
  ssh node$N "cd /homes/inho/Capybara/capybara; for p in 0 1 2 3; do c=\$((p+1)); tmux new-session -d -s hs\$p \"cd /homes/inho/Capybara/capybara && sudo -E env RECV_QUEUE_LEN_THRESHOLD=20 MIG_DELAY=0 MAX_REACTIVE_MIGS=$MR MAX_PROACTIVE_MIGS=0 MIG_PER_N=0 CONFIGURED_STATE_SIZE=0 MIN_THRESHOLD=1000000 RPS_THRESHOLD=0.3 THRESHOLD_EPSILON=0.1 CORE_ID=\$c CONFIG_PATH=scripts/config/node${N}_config.yaml MTU=9000 MSS=9000 NUM_CORES=4 USE_JUMBO=1 LIBOS=catnip DATA_SIZE=256 LD_LIBRARY_PATH=\\/homes/inho/lib:\\/homes/inho/lib/x86_64-linux-gnu numactl -m0 bin/examples/rust/http-server.elf 10.0.1.${N}:1000\$p >/tmp/ae-hs${N}_\$p.log 2>&1\"; sleep 2; done" >/dev/null 2>&1 &
done
wait

# 4) verify 12/12 fleet (poll up to 12s)
FLEET=0
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
  FLEET=$(for N in 8 9 10; do ssh node$N "pgrep -c http-server.el" 2>/dev/null; done | paste -sd+ | bc)
  [ "$FLEET" = "12" ] && break
  sleep 1
done
if [ "$FLEET" != "12" ]; then echo "FLEET=$FLEET (want 12) — run aborted"; exit 1; fi

# 5) shortflow client (12s runtime), then main client (10s runtime)
ZA=""; [ "$Z" != "0" ] && ZA="--zipf=$Z"
if [ "$COND" = "CAPY" ]; then
  tmux kill-session -t sf7 2>/dev/null; rm -f /tmp/ae-run_sf.log
  tmux new-session -d -s sf7 "cd /homes/inho/Capybara/caladan && sudo numactl -m0 apps/synthetic/target/release/synthetic 10.0.1.8:55555 --config client_node7_shortflow.config --mode runtime-client --protocol=http --transport=tcp --samples=1 --pps=100000 --threads=1 --runtime=12 --discard_pct=0 --output=trace --rampup=0 --shortflow --shortflow-duration=10000 --exptid=/tmp/ae-run_sf > /tmp/ae-run_sf.log 2>&1"
  sleep 2
  ssh node6 "cd /homes/inho/Capybara/caladan-n6; tmux kill-session -t cl6 2>/dev/null; rm -f /tmp/ae-run_main.log; tmux new-session -d -s cl6 \"cd /homes/inho/Capybara/caladan-n6 && sudo numactl -m0 apps/synthetic/target/release/synthetic 10.0.1.8:55555 --config client_node6.config --mode runtime-client --protocol=http --transport=tcp --samples=1 --pps=$PPS --threads=100 --runtime=10 --discard_pct=0 --output=trace --rampup=0 $ZA --exptid=/tmp/ae-run_main > /tmp/ae-run_main.log 2>&1\"" >/dev/null 2>&1
  # poll node6 for [RESULT] (up to 44s)
  for i in $(seq 1 22); do ssh node6 "grep -q '\[RESULT\]' /tmp/ae-run_main.log 2>/dev/null" && break; sleep 2; done
  MAIN=$(ssh node6 "grep '\[RESULT\]' /tmp/ae-run_main.log 2>/dev/null | tail -1")
  for i in $(seq 1 6); do SHORT99=$(grep -oE "99th \(us\): [0-9]+" /tmp/ae-run_sf.log 2>/dev/null | grep -oE "[0-9]+$" | tail -1); [ -n "$SHORT99" ] && break; sleep 2; done
else
  ssh node6 "cd /homes/inho/Capybara/caladan-n6; tmux kill-session -t sf6 2>/dev/null; rm -f /tmp/ae-run_sf.log; tmux new-session -d -s sf6 \"cd /homes/inho/Capybara/caladan-n6 && sudo numactl -m0 apps/synthetic/target/release/synthetic 10.0.1.8:55555 --config client_node6_shortflow.config --mode runtime-client --protocol=http --transport=tcp --samples=1 --pps=100000 --threads=10 --runtime=12 --discard_pct=0 --output=trace --rampup=0 --shortflow --shortflow-duration=10000 --exptid=/tmp/ae-run_sf > /tmp/ae-run_sf.log 2>&1\"" >/dev/null 2>&1
  sleep 2
  tmux kill-session -t cl7 2>/dev/null; rm -f /tmp/ae-run_main.log
  tmux new-session -d -s cl7 "cd /homes/inho/Capybara/caladan && sudo numactl -m0 apps/synthetic/target/release/synthetic 10.0.1.8:55555 --config client_node7.config --mode runtime-client --protocol=http --transport=tcp --samples=1 --pps=$PPS --threads=100 --runtime=10 --discard_pct=0 --output=trace --rampup=0 $ZA --exptid=/tmp/ae-run_main > /tmp/ae-run_main.log 2>&1"
  for i in $(seq 1 44); do grep -q "\[RESULT\]" /tmp/ae-run_main.log 2>/dev/null && break; sleep 1; done
  MAIN=$(grep "\[RESULT\]" /tmp/ae-run_main.log 2>/dev/null | tail -1)
  for i in $(seq 1 6); do SHORT99=$(ssh node6 "grep -oE '99th \(us\): [0-9]+' /tmp/ae-run_sf.log 2>/dev/null" | grep -oE "[0-9]+$" | tail -1); [ -n "$SHORT99" ] && break; sleep 2; done
fi

if [ -z "$MAIN" ]; then echo "no [RESULT] from main client — run failed"; exit 1; fi
echo "$COND,$Z,$RID,FLEET=$FLEET,${MAIN},SHORT_99=$SHORT99" >> $RES
echo "DONE $COND z=$Z r=$RID fleet=$FLEET p99=$(echo $MAIN | awk -F',' '{print $7}') short=$SHORT99"
