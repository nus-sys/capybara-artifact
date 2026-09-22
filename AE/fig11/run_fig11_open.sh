#!/bin/bash
# Fig11 open-loop panel: caladan synthetic from node7 (the era used node5, but
# that tree is now node7-built; identical role), 128 KB responses, 100
# connections, a single-pps run per rung exactly like the era's manual ladder.
# Gbps = achieved_rps * 131072 * 8 / 1e9 (the CSV convention).
# The SERVERS must already be running (use the per-system closed-loop runners'
# bring-up, or launch by hand); this script only drives the client ladder.
# usage: run_fig11_open.sh <label> <ip:port> "<pps list>" [runtime_s]
set -u
LABEL=$1; TARGET=$2; PPSL=$3; RT=${4:-10}
OUT=~/capybara-AE-runs/fig11/results_open.txt
C=/homes/inho/Capybara/caladan

pgrep -x iokerneld >/dev/null || {
  tmux kill-session -t iok7 2>/dev/null
  tmux new-session -d -s iok7 "cd $C && sudo ./iokerneld ias nicpci 0000:31:00.1 nobw > /tmp/ae-iok7.log 2>&1"
  sleep 5
  pgrep -x iokerneld >/dev/null || { echo "FATAL iokerneld"; exit 1; }
}

for PPS in $PPSL; do
  sudo pkill -x synthetic 2>/dev/null; sleep 1
  cd $C && sudo timeout $((RT + 50)) numactl -m0 apps/synthetic/target-fig11o/release/synthetic \
    $TARGET --config client_node7.config --mode runtime-client --protocol=http \
    --transport=tcp --samples=1 --pps=$PPS --threads=${THREADS:-100} --runtime=$RT \
    --discard_pct=10 --output=trace --rampup=0 --exptid=/tmp/ae-f11open > /tmp/ae-syn7.log 2>&1
  RC=$?
  R=$(grep -a "^\[RESULT\]" /tmp/ae-syn7.log | tail -1)
  if [ -z "$R" ]; then
    echo "RES open $LABEL pps=$PPS CLIENT-DIED rc=$RC" | tee -a $OUT
    continue
  fi
  ACH=$(echo "$R" | awk -F", " "{print \$2}")
  GBPS=$(python3 -c "print(round(int(\"$ACH\") * 131072 * 8 / 1e9, 3))" 2>/dev/null)
  echo "RES open $LABEL pps=$PPS achieved=$ACH gbps=$GBPS detail=${R#\[RESULT\] }" | tee -a $OUT
  sleep 2
done
