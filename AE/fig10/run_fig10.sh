#!/bin/bash
# ============================================================================
# Fig-10 one-command reproduction (SIGCOMM'26 Capybara AE)
#   Run on node7:  bash ~/capybara-AE-runs/fig10/run_fig10.sh [quick|full]
#   quick ~45 min, full ~80 min: switch bring-up (main_eval_fig10) -> peak sweep
#   (LWRR / Capybara / Uniform x 1/4/8/16/20 KB) -> grouped-bar figure -> restore.
#
# Uniform is the upper bound: the same 720 connections and the same offered load
# spread evenly over the 12 backends. LWRR and Capybara see the Zipf-1.2 skew.
# ============================================================================
set -u
D=~/capybara-AE-runs/fig10
MODE=${1:-full}
step(){ echo "[$(date +%H:%M:%S)] $*"; }

cleanup(){
  step "Cleanup"
  bash ~/capybara-AE-runs/cleanup_all.sh
}
trap cleanup EXIT
bash ~/capybara-AE-runs/arm_watchdog.sh 9000

step "Bring-up (~4 min)"
bash $D/fig10_bringup.sh || { echo "FATAL: bring-up failed"; exit 1; }

rm -f $D/fig10_results_mss8960.txt
bash $D/fig10_sweep_final.sh "$MODE" LWRR CAPY UNI 2>&1

step "Generating figure"
cd $D && python3 /homes/sigcomm26ae/capybara-AE-runs/paperplot/paper_style.py fig10 $D/fig10_results_mss8960.txt $D/fig10_reproduction
step "DONE. Figure: $D/fig10_reproduction.png (+ .pdf), raw: $D/fig10_results_mss8960.txt"
