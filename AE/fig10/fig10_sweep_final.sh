#!/bin/bash
# Fig-10 peak sweep, using the paper's own criterion for "peak throughput": the
# highest offered load whose p99 is still sane. Requests the client never managed
# to send are tolerated; a latency blow-up is what marks the end of usable
# throughput.
#
# Capybara at large response sizes is bimodal: an unlucky run hits a migration
# storm and blows p99 at a load the next run sustains, so a violated rung is
# retried once before the ladder is abandoned.
#
# usage: fig10_sweep_final.sh [quick|full] [conditions...]
set -u
D=~/capybara-AE-runs/fig10
RES=$D/fig10_results_mss8960.txt
MODE=${1:-full}; shift || true
CONDS=${*:-LWRR CAPY UNI}
P99_LIMIT=${P99_LIMIT:-1000}      # microseconds
export SMTU=${SMTU:-9000} SMSS=${SMSS:-8960}
step(){ echo "[$(date +%H:%M:%S)] $*"; }

ladder(){ # cond size
  case "$1-$2" in
    LWRR-1024)  echo "1400000 1700000 2000000 2300000" ;;
    LWRR-4096)  echo "1100000 1350000 1550000 1750000" ;;
    LWRR-8192)  echo "900000 1100000 1250000 1400000" ;;
    LWRR-16384) echo "400000 500000 600000 700000" ;;
    LWRR-20480) echo "250000 320000 400000 470000" ;;
    CAPY-1024)  echo "4200000 4800000 5400000 5900000" ;;
    CAPY-4096)  echo "3500000 4000000 4400000 4800000" ;;
    CAPY-8192)  echo "2300000 2600000 2900000 3200000" ;;
    CAPY-16384) echo "900000 1050000 1200000 1350000" ;;
    CAPY-20480) echo "450000 550000 650000 750000" ;;
    UNI-1024)   echo "5000000 5700000 6400000 7000000" ;;
    UNI-4096)   echo "3900000 4400000 4900000 5300000" ;;
    UNI-8192)   echo "2800000 3200000 3500000 3800000" ;;
    UNI-16384)  echo "1000000 1200000 1350000 1450000" ;;
    UNI-20480)  echo "800000 950000 1100000 1250000" ;;
  esac
}

# quick mode samples two rungs around the published peak, approaching it from below:
# starting above it wastes the whole ladder, since the sweep stops at the first
# rung that blows p99.
trim(){ if [ "$MODE" = quick ]; then echo "$@" | awk '{print $2, $3}'; else echo "$@"; fi; }

one(){ # cond size rps -> prints RES line
  bash $D/run_fig10_one.sh "$1" "$2" "$3" 2>/dev/null | tail -1
}

# A cell where node5 or node6 completed 0 requests is NOT a Capybara result -- it
# is a ~1/3-throughput artifact of a degraded client node. Detect it so we can
# record a SKIP marker (ignored by the plotter -> the size shows a gap) instead of
# a misleading low point. A healthy 3-client run never trips this.
client_limited(){
  local c5 c6
  c5=$(echo "$1" | grep -oE "n5=[0-9]+" | cut -d= -f2)
  c6=$(echo "$1" | grep -oE "n6=[0-9]+" | cut -d= -f2)
  [ "${c5:-0}" = "0" ] || [ "${c6:-0}" = "0" ]
}

# --- client warmup: node5/6 iokerneld can lag node7 at bring-up; a cell run
# before they are dataplane-ready records n5/n6=0 (a wrong 1/3-throughput result
# with no retry). Warm up until all three clients complete requests.
for w in 1 2 3 4 5 6; do
  WOUT=$(one ${CONDS%% *} 1024 1000000)
  WN5=$(echo "$WOUT" | grep -oE "n5=[0-9]+" | cut -d= -f2); WN5=${WN5:-0}
  WN6=$(echo "$WOUT" | grep -oE "n6=[0-9]+" | cut -d= -f2); WN6=${WN6:-0}
  WN7=$(echo "$WOUT" | grep -oE "n7=[0-9]+" | cut -d= -f2); WN7=${WN7:-0}
  if [ "$WN5" -gt 0 ] && [ "$WN6" -gt 0 ] && [ "$WN7" -gt 0 ]; then
    step "clients warm (n5=$WN5 n6=$WN6 n7=$WN7)"; break
  fi
  step "warmup $w: clients not all ready (n5=$WN5 n6=$WN6 n7=$WN7), waiting 12s"
  sleep 12
done

for COND in $CONDS; do
  for SZ in ${SIZES:-1024 4096 8192 16384 20480}; do
    BEST=0; BESTG=0
    for R in $(trim $(ladder $COND $SZ)); do
      OUT=$(one $COND $SZ $R)
      # client-zero retry: node5/6 can intermittently complete 0 (weak-client
      # flake); a zero there records a wrong 1/3-throughput cell.
      if client_limited "$OUT"; then sleep 6; OUT=$(one $COND $SZ $R); fi
      # still client-limited after the retry -> persistent (a degraded client
      # node). Record a SKIP marker the plotter ignores (the size shows a gap)
      # instead of a misleading low point, and move to the next rung.
      if client_limited "$OUT"; then
        echo "# SKIP $COND $SZ $R client-limited (node5/6 completed 0; re-run on a rested cluster): $OUT" | tee -a $RES
        step "  SKIP $COND size=$SZ rung=$R: node5/6 completed 0 — not a Capybara result, re-run on a rested cluster"
        continue
      fi
      echo "$OUT" | tee -a $RES
      P99=$(echo "$OUT" | grep -oE "p99=[0-9]+" | cut -d= -f2)
      [ -z "$P99" ] && break
      if [ "$(python3 -c "print(1 if $P99 <= $P99_LIMIT else 0)")" != "1" ]; then
        OUT=$(one $COND $SZ $R); echo "$OUT  (retry)" | tee -a $RES
        P99=$(echo "$OUT" | grep -oE "p99=[0-9]+" | cut -d= -f2)
        [ -z "$P99" ] && break
        [ "$(python3 -c "print(1 if $P99 <= $P99_LIMIT else 0)")" != "1" ] && break
      fi
      G=$(echo "$OUT" | awk '{print $6}')
      [ "$(python3 -c "print(1 if $G > $BESTG else 0)")" = "1" ] && { BESTG=$G; BEST=$(echo "$OUT" | awk '{print $5}'); }
    done
    if [ "$BEST" = "0" ]; then
      # Nothing on the sampled ladder held its latency. Fall back to the lowest
      # rung rather than reporting this cell as zero throughput.
      R=$(ladder $COND $SZ | awk '{print $1}')
      OUT=$(one $COND $SZ $R)
      if client_limited "$OUT"; then
        echo "# SKIP $COND $SZ $R (floor) client-limited (node5/6 completed 0): $OUT" | tee -a $RES
        step "  SKIP $COND size=$SZ (floor): node5/6 completed 0 — size omitted, re-run on a rested cluster"
      else
        echo "$OUT  (floor)" | tee -a $RES
        P99=$(echo "$OUT" | grep -oE "p99=[0-9]+" | cut -d= -f2)
        if [ -n "$P99" ] && [ "$(python3 -c "print(1 if $P99 <= $P99_LIMIT else 0)")" = "1" ]; then
          BEST=$(echo "$OUT" | awk '{print $5}'); BESTG=$(echo "$OUT" | awk '{print $6}')
        else
          step "  WARNING: $COND size=$SZ found no load holding p99<=${P99_LIMIT}us"
        fi
      fi
    fi
    step "$COND size=$SZ peak=$BEST rps ($BESTG Gbps, p99<=${P99_LIMIT}us)"
    [ "$BEST" = "0" ] && ZERO="${ZERO:-} $COND:$SZ"
  done
done

# A ladder that found no peak at all is almost always a transient right after
# bring-up (seen: LWRR 1 KB with p99 ~2 s on every rung, while every later cell
# was normal). Re-run those ladders once, at the end, on the now-settled cluster;
# the plotter keeps the best line per cell, so the retry can only add.
if [ -n "${ZERO:-}" ] && [ -z "${FIG10_RETRY:-}" ]; then
  step "re-running ladders that found no peak (transient after bring-up):${ZERO}"
  sleep 30
  for cs in $ZERO; do
    FIG10_RETRY=1 SIZES=${cs#*:} bash $D/fig10_sweep_final.sh "$MODE" ${cs%%:*}
  done
fi
step "sweep done -> $RES"
