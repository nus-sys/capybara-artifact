#!/bin/bash
# ============================================================================
# Fig. 13 reproduction — peak throughput vs number of servers, Capybara (Tofino
# switch) and Capybara-SW (Capybara's software switch on an end host)
#   Run on node7:  bash ~/capybara-AE-runs/fig13/run_fig13.sh [quick|full]
#   Single cells:  ONLY_N="1" SKIP_HW=1 bash ~/capybara-AE-runs/fig13/run_fig13.sh   (SW column, N=1 only)
#   quick: 1 / 4 / 12 servers (~35 min)      full: 1 / 2 / 4 / 8 / 12 servers (~60 min)
#
# Capybara column: the Fig 10 switch program (main_eval_fig10, 12 backends on
# node8/9/10) with the three caladan clients spreading a uniform open-loop load over
# the first N server groups only; the cell's value is the highest offered load whose
# p99 stays below P99_LIMIT (the paper's peak criterion, as in Fig 10).
# Capybara-SW column: the switch only forwards (endhost_switch program); Capybara's
# software switch (capybara-switch, one core on node7) round-robins new connections
# over N backends on node8/9/10; two open-loop clients (node5/6, 128 connections
# each) step the offered load up; same peak criterion. The software switch is the
# paper-era tree, the backends are the Fig 10 server tree (see README).
# ============================================================================
set -u
MODE=${1:-full}
SKIP_SW=${SKIP_SW:-0}    # SKIP_SW=1 measures only the hardware-switch column; SKIP_HW=1 only the software-switch column
D=~/capybara-AE-runs/fig13
F10=~/capybara-AE-runs/fig10
SZ=${SZ:-256}
P99_LIMIT=${P99_LIMIT:-1000}
step(){ echo "[$(date +%H:%M:%S)] $*"; }
cleanup(){ step "Cleanup"; bash ~/capybara-AE-runs/cleanup_all.sh; }
trap cleanup EXIT
bash ~/capybara-AE-runs/arm_watchdog.sh 5400 >/dev/null 2>&1

case $MODE in
  quick) NS="1 4 12" ;;
  *)     NS="1 2 4 8 12" ;;
esac
[ -n "${ONLY_N:-}" ] && NS="$ONLY_N"    # ONLY_N="1" re-measures single cells (with SKIP_HW=1 / SKIP_SW=1 for one column)
OUT=$D/results_fig13.txt
: > $OUT

# ---------------------------------------------------------------- Capybara (hardware switch)
# Peak = the highest achieved rate with p99 under the limit while the achieved rate still
# grows with the offered load (>2% over the previous rung). The offered/achieved ratio is
# not a criterion: the load generators' timer-paced send threads skip part of their
# schedule as "late" at low per-client rates (10-25% on node5/6), which is a client
# property, not server saturation; a rung whose achieved rate falls below 60% of the
# offered one (clients collapsing under connect timeouts) ends the ladder. (The limit was
# 70% until 2026-10-10: at the first N=1 rung of the SW column the clients achieved 69%.)
hw_ladder(){ local n=$1 r; for per in 400000 480000 560000 640000 720000 800000; do r=$((n * per)); [ $r -gt 7500000 ] && r=7500000; echo $r; done | sort -nu; }
if [ "${SKIP_HW:-0}" = 1 ]; then NS_HW=""; else NS_HW="$NS"; step "Capybara (hardware switch): Fig 10 bring-up"; bash $F10/fig10_bringup.sh || { echo "FATAL: bring-up failed"; exit 1; }; fi
for N in $NS_HW; do
  step "hw: N=$N servers"
  BEST=0; BESTP=NA
  for RPS in $(hw_ladder $N); do
    OKR=0
    for attempt in 1 2; do
      L=$(SPREAD=top$N RT=3 bash $F10/run_fig10_one.sh SOLO $SZ $RPS 2>&1 | grep "^RES" | tail -1)
      ACH=$(echo "$L" | awk '{print $5+0}'); P99=$(echo "$L" | grep -oE "p99=[0-9]+" | cut -d= -f2)
      echo "  $L"
      if [ -n "$P99" ] && [ "$P99" -gt 0 ] && [ "$P99" -le "$P99_LIMIT" ] && [ $((ACH * 100)) -gt $((BEST * 102)) ] && [ $((ACH * 10)) -ge $((RPS * 6)) ]; then OKR=1; BEST=$ACH; BESTP=$P99; break; fi
    done
    [ $OKR = 1 ] || break
  done
  echo "RES fig13 hw servers=$N size=$SZ peak_rps=$BEST p99=$BESTP" | tee -a $OUT
done
bash ~/capybara-AE-runs/cleanup_all.sh >/dev/null 2>&1

# ---------------------------------------------------------------- Capybara-SW (software switch on node7)
# SW column: same peak rule; the ladder is denser around the software switch's limit
sw_ladder(){ if [ $1 = 1 ]; then echo "300000 400000 500000 600000 700000 800000"; else echo "500000 700000 850000 1000000 1150000 1300000 1500000"; fi; }
if [ "$SKIP_SW" = 1 ]; then NS_SW=""; else NS_SW="$NS"; step "Capybara-SW: bring-up (plain L2 switch program, software switch on node7, clients node5/6)"; bash $D/fig13_sw_bringup.sh || { echo "FATAL: SW bring-up failed"; exit 1; }; fi
for N in $NS_SW; do
  step "sw: N=$N backends"
  BEST=0; BESTP=NA
  for RPS in $(sw_ladder $N); do
    OKR=0
    for attempt in 1 2; do
      L=$(DATA_SIZE=$SZ bash $D/run_fig13_sw_one.sh $N $RPS 2>&1 | grep "^RES" | tail -1)
      ACH=$(echo "$L" | awk '{print $5+0}'); P99=$(echo "$L" | grep -oE "p99=[0-9]+" | cut -d= -f2)
      echo "  $L"
      if [ -n "$P99" ] && [ "$P99" -gt 0 ] && [ "$P99" -le "$P99_LIMIT" ] && [ $((ACH * 100)) -gt $((BEST * 102)) ] && [ $((ACH * 10)) -ge $((RPS * 6)) ]; then OKR=1; BEST=$ACH; BESTP=$P99; break; fi
    done
    [ $OKR = 1 ] || break
  done
  echo "RES fig13 sw servers=$N size=$SZ peak_rps=$BEST p99=$BESTP" | tee -a $OUT
done

step "Figure"
cd $D && python3 ~/capybara-AE-runs/paperplot/paper_style.py fig13 $OUT $D/paper_ref/server_scalability_openloop_l4.csv $D/fig13_reproduction
step "DONE. Figure: $D/fig13_reproduction.png (+ .pdf); rows: $OUT"
