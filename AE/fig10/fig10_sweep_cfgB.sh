#!/bin/bash
# Fig-10 adaptive peak sweep. usage: fig10_sweep.sh <COND> [COND...]
# For each size, climb the ladder until achieved < 93% of target (or drop), record all.
set -u
D=~/capybara-AE-runs/fig10
RES=$D/fig10_results_cfgB.txt
step(){ echo "[$(date +%H:%M:%S)] $*"; }

ladder(){ # size -> ladder of total rps targets
  case $1 in
    1024)  echo "2000000 3000000 4000000 5000000 6000000" ;;
    4096)  echo "1500000 2500000 3500000 4200000 4800000" ;;
    8192)  echo "1000000 1600000 2200000 2600000 3000000" ;;
    16384) echo "700000 1000000 1300000 1500000 1700000" ;;
    20480) echo "600000 850000 1100000 1300000 1500000" ;;
  esac
}

for COND in "$@"; do
  for SZ in ${SIZES:-1024 4096 8192}; do
    BEST=0
    for R in $(ladder $SZ); do
      OUT=$(bash $D/run_fig10_cfgB.sh $COND $SZ $R 2>/dev/null | tail -1)
      echo "$OUT" | tee -a $RES
      ACH=$(echo $OUT | awk "{print \$5}")
      [ -z "$ACH" ] && ACH=0
      # peak = the highest offered load the system still keeps up with; past that a
      # server is saturated and the run no longer represents usable throughput
      PCTOK=$(python3 -c "print(1 if $ACH >= 0.93*$R else 0)")
      [ "$PCTOK" = "1" ] && [ "$ACH" -gt "$BEST" ] && BEST=$ACH
      [ "$PCTOK" = "0" ] && break
    done
    step "$COND size=$SZ peak_achieved=$BEST"
  done
done
step "sweep done"
