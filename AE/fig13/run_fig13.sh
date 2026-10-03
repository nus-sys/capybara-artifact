#!/bin/bash
# ============================================================================
# Fig. 13 reproduction — peak throughput vs number of servers, Capybara (Tofino
# switch) and Capybara-SW (Capybara's software switch on an end host)
#   Run on node7:  bash ~/capybara-AE-runs/fig13/run_fig13.sh [quick|full]
#   quick: 1 / 4 / 12 servers (~25 min)      full: 1 / 2 / 4 / 8 / 12 servers (~40 min)
#
# Capybara column: the Fig 10 switch program (main_eval_fig10, 12 backends on
# node8/9/10) with the three caladan clients spreading a uniform open-loop load over
# the first N server groups only; the cell's value is the highest offered load whose
# p99 stays below P99_LIMIT (the paper's peak criterion, as in Fig 10).
# Capybara-SW column: the switch only forwards (endhost_switch program); Capybara's
# software switch (capybara-switch.elf, one core on node8) round-robins new
# connections over N backends; one open-loop client on node7 with 128 connections
# steps the offered load up; same peak criterion. Both use the paper-era server tree
# for the SW column and the Fig 10 tree for the hardware column (see README).
# ============================================================================
set -u
MODE=${1:-full}
SKIP_SW=${SKIP_SW:-1}    # default: hardware-switch column only (see README on the software switch)
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
OUT=$D/results_fig13.txt
: > $OUT

# ---------------------------------------------------------------- Capybara (hardware switch)
hw_ladder(){ local n=$1 r; for per in 400000 480000 560000 640000; do r=$((n * per)); [ $r -gt 7500000 ] && r=7500000; echo $r; done | sort -nu; }
step "Capybara (hardware switch): Fig 10 bring-up"
bash $F10/fig10_bringup.sh || { echo "FATAL: bring-up failed"; exit 1; }
for N in $NS; do
  step "hw: N=$N servers"
  BEST=0; BESTP=NA
  for RPS in $(hw_ladder $N); do
    OKR=0
    for attempt in 1 2; do
      L=$(SPREAD=top$N RT=3 bash $F10/run_fig10_one.sh SOLO $SZ $RPS 2>&1 | grep "^RES" | tail -1)
      ACH=$(echo "$L" | awk '{print $5+0}'); P99=$(echo "$L" | grep -oE "p99=[0-9]+" | cut -d= -f2)
      echo "  $L"
      if [ -n "$P99" ] && [ "$P99" -le "$P99_LIMIT" ] && [ $((ACH * 10)) -ge $((RPS * 9)) ]; then OKR=1; BEST=$ACH; BESTP=$P99; break; fi
    done
    [ $OKR = 1 ] || break
  done
  echo "RES fig13 hw servers=$N size=$SZ peak_rps=$BEST p99=$BESTP" | tee -a $OUT
done
bash ~/capybara-AE-runs/cleanup_all.sh >/dev/null 2>&1

# ---------------------------------------------------------------- Capybara-SW (software switch on node8)
sw_ladder(){ if [ $1 = 1 ]; then echo "300000 400000 480000 540000 600000"; else echo "600000 800000 900000 950000 1000000 1050000 1100000"; fi; }
if [ "$SKIP_SW" = 1 ]; then NS_SW=""; else NS_SW="$NS"; step "Capybara-SW: bring-up (plain L2 switch program, node7 client)"; bash $D/fig13_sw_bringup.sh || { echo "FATAL: SW bring-up failed"; exit 1; }; fi
for N in $NS_SW; do
  [ "$N" -le 8 ] || { echo "RES fig13 sw servers=$N size=$SZ peak_rps=0 p99=NA note=not-measured(switch-bound-flat-from-2-servers)" | tee -a $OUT; continue; }
  step "sw: N=$N backends"
  BEST=0; BESTP=NA
  for RPS in $(sw_ladder $N); do
    OKR=0
    for attempt in 1 2; do
      L=$(DATA_SIZE=$SZ bash $D/run_fig13_sw_one.sh $N $RPS 2>&1 | grep "^RES" | tail -1)
      ACH=$(echo "$L" | awk '{print $4+0}'); P99=$(echo "$L" | grep -oE "p99=[0-9]+" | cut -d= -f2)
      echo "  $L"
      if [ -n "$P99" ] && [ "$P99" -le "$P99_LIMIT" ] && [ $((ACH * 10)) -ge $((RPS * 9)) ]; then OKR=1; BEST=$ACH; BESTP=$P99; break; fi
    done
    [ $OKR = 1 ] || break
  done
  echo "RES fig13 sw servers=$N size=$SZ peak_rps=$BEST p99=$BESTP" | tee -a $OUT
done

step "Figure"
cd $D && python3 ~/capybara-AE-runs/paperplot/paper_style.py fig13 $OUT $D/paper_ref/server_scalability_openloop_l4.csv $D/fig13_reproduction
step "DONE. Figure: $D/fig13_reproduction.png (+ .pdf); rows: $OUT"
