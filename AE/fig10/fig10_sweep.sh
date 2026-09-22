#!/bin/bash
# Fig-10 adaptive peak sweep. usage: fig10_sweep.sh <COND> [COND...]
# For each size, climb the ladder until achieved < 93% of target (or drop), record all.
set -u
D=~/capybara-AE-runs/fig10
RES=$D/fig10_results.txt
step(){ echo "[$(date +%H:%M:%S)] $*"; }

ladder(){ # size -> ladder of total rps targets
  case $1 in
    1024)  echo "3000000 4500000 5500000 6000000 6400000 6600000 6800000" ;;
    4096)  echo "2000000 3200000 4000000 4600000 5000000 5200000 5400000" ;;
    8192)  echo "1400000 2200000 2800000 3200000 3600000 3900000 4200000" ;;
    16384) echo "1200000 1600000 2000000 2400000 2800000" ;;
    20480) echo "1000000 1400000 1800000 2200000 2600000" ;;
  esac
}

for COND in "$@"; do
  for SZ in ${SIZES:-1024 4096 8192}; do
    BEST=0
    for R in $(ladder $SZ); do
      OUT=$(bash $D/run_fig10_one.sh $COND $SZ $R 2>/dev/null | tail -1)
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
