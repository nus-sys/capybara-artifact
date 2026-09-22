#!/bin/bash
# Per-server capacity ladder, the way the paper's spreadsheet measured it:
# ONE backend, 100 connections, one client, no migration.
# usage: percore_cap.sh <size> <rps1> [rps2 ...]
set -u
SZ=$1; shift
T=/homes/inho/Capybara/capybara-fig10

# single backend on node8:10000; all switch slots already point at index 0 (see be0_only.py)
ssh node8 "sudo pkill -x http-server.elf 2>/dev/null; for p in 0 1 2 3; do tmux kill-session -t hs\$p 2>/dev/null; done; true" >/dev/null 2>&1
for N in 9 10; do ssh node$N "sudo pkill -x http-server.elf 2>/dev/null; for p in 0 1 2 3; do tmux kill-session -t hs\$p 2>/dev/null; done; true" >/dev/null 2>&1; done
ssh node8 "sudo pkill -x dpdk-ctrl.elf 2>/dev/null; tmux kill-session -t dc8 2>/dev/null; true" >/dev/null 2>&1
sleep 2
ssh node8 "tmux new-session -d -s dc8 \"cd $T && MTU=9216 timeout 1200 make PREFIX=/homes/inho dpdk-ctrl-node8 > /tmp/ae-dc8.log 2>&1\"" >/dev/null 2>&1
sleep 14
ssh node8 "tmux new-session -d -s hs0 \"cd $T && sudo -E env SIGNAL_POLICY_MIGS=0 MAX_REACTIVE_MIGS=0 MAX_PROACTIVE_MIGS=0 RECV_QUEUE_LEN_THRESHOLD=1000000 MIG_DELAY=0 MIG_PER_N=10 CONFIGURED_STATE_SIZE=0 MIN_THRESHOLD=1000000 RPS_THRESHOLD=0.3 THRESHOLD_EPSILON=0.1 CORE_ID=1 CONFIG_PATH=scripts/config/node8_config.yaml MTU=9216 MSS=9000 NUM_CORES=4 USE_JUMBO=1 LIBOS=catnip DATA_SIZE=$SZ LD_LIBRARY_PATH=\\/homes/inho/lib:\\/homes/inho/lib/x86_64-linux-gnu timeout 900 numactl -m0 bin/examples/rust/http-server.elf 10.0.1.8:10000 >/tmp/ae-hs8_0.log 2>&1\"" >/dev/null 2>&1
sleep 5
[ "$(ssh node8 'pgrep -c http-server.el' 2>/dev/null)" = "1" ] || { echo "server failed"; exit 1; }

for R in "$@"; do
  tmux kill-session -t cap 2>/dev/null; sudo pkill -x synthetic 2>/dev/null; sudo rm -f /tmp/ae-cap.log
  tmux new-session -d -s cap "cd /homes/inho/Capybara/caladan-fig8 && sudo timeout 120 numactl -m0 apps/synthetic/target-fig10/release/synthetic 10.0.1.8:55555 --config client_node7.config --mode runtime-client --protocol=http --transport=tcp --samples=1 --pps=$R --threads=100 --runtime=3 --discard_pct=0 --output=buckets --rampup=0 > /tmp/ae-cap.log 2>&1"
  for i in $(seq 1 40); do pgrep -x synthetic >/dev/null || break; sleep 1; done
  sleep 1
  L=$(strings /tmp/ae-cap.log | grep -m1 "\[RESULT\]")
  ACH=$(echo "$L" | awk -F", " '{print $2+0}')
  DROP=$(echo "$L" | awk -F", " '{print $3+0}')
  NS=$(echo "$L" | awk -F", " '{print $4+0}')
  P99=$(echo "$L" | awk -F", " '{print $7}')
  G=$(python3 -c "print(f'{$ACH*$SZ*8/1e9:.1f}')" 2>/dev/null)
  echo "CAP $SZ target=$R achieved=$ACH gbps=$G dropped=$DROP neversent=$NS p99=$P99"
done
ssh node8 "sudo pkill -x http-server.elf 2>/dev/null; true" >/dev/null 2>&1
