#!/bin/bash
# ============================================================================
# Fig-8 one-command reproduction (SIGCOMM'26 Capybara AE)
#   Run on node7:  bash ~/capybara-AE-runs/fig8/run_fig8.sh
#   ~10 min total: switch bring-up (dedicated main_eval_fig8 P4) -> LWRR /
#   Capybara-Reactive / Capybara runs -> 3-panel figure -> cluster restore.
# ============================================================================
set -u
D=~/capybara-AE-runs/fig8
step(){ echo "[$(date +%H:%M:%S)] $*"; }

cleanup(){
  step "Cleanup: stopping servers/clients, restoring switch baseline"
  tmux kill-session -t f8c 2>/dev/null; sudo pkill -x synthetic 2>/dev/null
  tmux kill-session -t iok7 2>/dev/null; sudo pkill -x iokerneld 2>/dev/null
  ssh node9 "sudo pkill -INT -x http-server.elf 2>/dev/null; sleep 1; sudo pkill -x http-server.elf 2>/dev/null; sudo pkill -x dpdk-ctrl.elf 2>/dev/null; for p in 0 1; do tmux kill-session -t f8s\$p 2>/dev/null; done; tmux kill-session -t dc9 2>/dev/null; true" >/dev/null 2>&1
  ssh sw1 'for s in sw bft swset pktgen; do tmux kill-session -t $s 2>/dev/null; done; sudo pkill -x bf_switchd 2>/dev/null; sleep 3; tmux new-session -d -s baseline "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_switchd.sh -p port_forward > /tmp/ae-baseline.log 2>&1"' >/dev/null 2>&1
  sleep 50
  ssh sw1 'tmux new-session -d -s blcfg "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /home/singtel/inho/Capybara/capybara/p4/port_forward/port_forward.py > /tmp/ae-blcfg.log 2>&1"' >/dev/null 2>&1
  step "Cleanup done (switch back on port_forward baseline)"
}
trap cleanup EXIT

step "Preflight"
for N in 9; do ssh -o ConnectTimeout=5 node$N true >/dev/null 2>&1 || { echo "FATAL: node$N unreachable"; exit 1; }; done
ssh -o ConnectTimeout=5 sw1 true >/dev/null 2>&1 || { echo "FATAL: sw1 unreachable"; exit 1; }

step "Bring-up (switch main_eval_fig8 + iokerneld, ~4 min)"
bash $D/fig8_bringup.sh || { echo "FATAL: bring-up failed"; exit 1; }

# Clear this run's experiment ids first, so a failed measurement can never be
# plotted from files left behind by an earlier one. The authors' copies are
# kept in fig8-frozen/.
PREV=$HOME/capybara-data/prev-$(date +%Y%m%d-%H%M%S)
for C in LWRR REACT CAPY; do
  if ls $HOME/capybara-data/fig8$C-run1.* >/dev/null 2>&1; then
    mkdir -p $PREV && mv $HOME/capybara-data/fig8$C-run1.* $PREV/
  fi
done
[ -d "$PREV" ] && step "Archived previous data -> $PREV" || true

for C in LWRR REACT CAPY; do
  step "Running $C"
  bash $D/run_fig8_one.sh $C run1 || { step "$C failed - retrying once"; bash $D/run_fig8_one.sh $C run1 || { echo "FATAL: $C failed twice - refusing to plot"; exit 1; }; }
done

step "Generating figure"
cd $D && python3 /homes/sigcomm26ae/capybara-AE-runs/paperplot/paper_style.py fig8 fig8LWRR-run1 fig8REACT-run1 fig8CAPY-run1 $D/fig8_reproduction
step "DONE. Figure: $D/fig8_reproduction.png (+ .pdf)"
