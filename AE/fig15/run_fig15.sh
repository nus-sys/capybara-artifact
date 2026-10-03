#!/bin/bash
# ============================================================================
# Fig. 15 reproduction — throughput of one TCP connection vs migration frequency
#   Run on node7:  bash ~/capybara-AE-runs/fig15/run_fig15.sh [quick|full]
#   quick: sizes 1/16/64 KB x 0/100/10000 mig/s  (~10 min)
#   full : sizes 1/8/16/32/64 KB x 0/1/10/100/1000/10000 mig/s (~35 min, the figure)
#
# One open-loop caladan connection (node7) -> VIP 10.0.1.8:55555 -> two backends
# on node9 (main_eval_fig8 switch program, as Fig 8). The backends are the Fig 8
# tree built with the manual (time-gated) migration feature: every MIG_PER_N us
# the backend holding the connection hands it to the other one. For each cell
# the offered load is swept and the peak achieved request rate is converted to
# Gbps of HTTP response bytes. Restores the cluster on exit (also on Ctrl-C).
# ============================================================================
set -u
MODE=${1:-full}
D=~/capybara-AE-runs/fig15
step(){ echo "[$(date +%H:%M:%S)] $*"; }

cleanup(){ step "Cleanup"; bash ~/capybara-AE-runs/cleanup_all.sh; }
trap cleanup EXIT
bash ~/capybara-AE-runs/arm_watchdog.sh 5400 >/dev/null 2>&1

case $MODE in
  quick) SIZES="1024 16384 65536";             FREQS="0 100 10000" ;;
  *)     SIZES="1024 8192 16384 32768 65536";  FREQS="0 1 10 100 1000 10000" ;;
esac

# jumbo responses (>= 4 KB) need the client port at a jumbo MTU (as in Fig 10), and the
# MTU must be set BEFORE the iokernel attaches to the port (changing it later resets the port)
step "Client port MTU -> 9216"
sudo ip link set ens85f1np1 mtu 9216 2>/dev/null
step "Bring-up: switch main_eval_fig8 + pktgen, iokerneld on node7 (shared with Fig 8)"
bash ~/capybara-AE-runs/fig8/fig8_bringup.sh || { echo "FATAL: bring-up failed"; exit 1; }

export OUT=$D/results_fig15.txt
: > $OUT
for SZ in $SIZES; do
  for F in $FREQS; do
    step "cell: response $((SZ/1024)) KB, $F migrations/s"
    bash $D/run_fig15_one.sh $SZ $F 2>&1 | grep "^RES" | sed 's/ detail=.*//'
  done
done

step "Figure"
cd $D && python3 ~/capybara-AE-runs/paperplot/paper_style.py fig15 $OUT $D/paper_ref/tput_vs_mig_freq.csv $D/fig15_reproduction
step "DONE. Figure: $D/fig15_reproduction.png (+ .pdf); rows: $OUT"
