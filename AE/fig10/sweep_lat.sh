#!/bin/bash
# Fig-10 sweep with the paper's own peak criterion: the highest offered load whose
# p99 is still sane. Requests the client never managed to send are tolerated; a
# latency blow-up is what marks the end of usable throughput.
set -u
D=~/capybara-AE-runs/fig10
RES=$D/fig10_results_lat.txt
P99_LIMIT=${P99_LIMIT:-1000}      # microseconds
step(){ echo "[$(date +%H:%M:%S)] $*"; }

ladder(){ # cond size
  case "$1-$2" in
    LWRR-1024)  echo "1000000 1400000 1800000 2200000 2600000" ;;
    LWRR-4096)  echo "800000 1100000 1400000 1700000 2000000" ;;
    LWRR-8192)  echo "600000 900000 1200000 1500000 1800000" ;;
    LWRR-16384) echo "300000 450000 600000 750000 900000" ;;
    LWRR-20480) echo "250000 400000 550000 700000 850000" ;;
    *-1024)     echo "3000000 4000000 5000000 5800000 6400000" ;;
    *-4096)     echo "2000000 3000000 3800000 4400000 5000000" ;;
    *-8192)     echo "1400000 2000000 2600000 3200000 3800000" ;;
    *-16384)    echo "600000 900000 1200000 1500000 1800000" ;;
    *-20480)    echo "500000 750000 1000000 1250000 1500000" ;;
  esac
}

for COND in "$@"; do
  for SZ in ${SIZES:-1024 4096 8192 16384 20480}; do
    BEST=0; BESTG=0
    for R in $(ladder $COND $SZ); do
      OUT=$(bash $D/run_fig10_one.sh $COND $SZ $R 2>/dev/null | tail -1)
      echo "$OUT" | tee -a $RES
      P99=$(echo "$OUT" | grep -oE "p99=[0-9]+" | cut -d= -f2)
      ACH=$(echo "$OUT" | awk '{print $5}')
      [ -z "$P99" ] && break
      OKLAT=$(python3 -c "print(1 if $P99 <= $P99_LIMIT else 0)")
      if [ "$OKLAT" = "1" ]; then
        [ "$ACH" -gt "$BEST" ] && { BEST=$ACH; BESTG=$(echo "$OUT" | awk '{print $6}'); }
      else
        break
      fi
    done
    step "$COND size=$SZ peak=$BEST rps ($BESTG Gbps, p99<=${P99_LIMIT}us)"
  done
done
step "latency-based sweep done"
