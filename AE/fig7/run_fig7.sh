#!/bin/bash
# ============================================================================
# Fig-7 one-command reproduction (SIGCOMM'26 Capybara AE)
#   Run on node7:  bash ~/capybara-AE-runs/fig7/run_fig7.sh [quick|full]
#     quick = 3 runs/cell (~20 min)   full = 10 runs/cell (~60 min, the paper protocol)
#   Measures from scratch every time. Any existing fig7_results.txt is archived
#   to fig7_results.<timestamp>.prev.txt before the sweep starts.
#   Pass a third argument 'resume' to reuse completed runs instead (e.g. after a
#   dropped connection): bash run_fig7.sh full resume
# ============================================================================
set -u
MODE=${1:-full}
RESUME=${2:-fresh}
RUNS=10; [ "$MODE" = "quick" ] && RUNS=3
D=~/capybara-AE-runs/fig7
RES=$D/fig7_results.txt
step(){ echo "[$(date +%H:%M:%S)] $*"; }

cleanup(){
  step "Cleanup: stopping clients/servers, restoring switch baseline"
  tmux kill-session -t wdog 2>/dev/null   # disarm deadman watchdog (we are cleaning up)
  tmux kill-session -t cl7 2>/dev/null; tmux kill-session -t sf7 2>/dev/null
  sudo pkill -x synthetic 2>/dev/null
  ssh node6 "tmux kill-session -t cl6 2>/dev/null; tmux kill-session -t sf6 2>/dev/null; sudo pkill -x synthetic 2>/dev/null; tmux kill-session -t iok6 2>/dev/null; sudo pkill -x iokerneld 2>/dev/null; true" >/dev/null 2>&1
  tmux kill-session -t iok7 2>/dev/null; sudo pkill -x iokerneld 2>/dev/null
  for N in 8 9 10; do ssh node$N "sudo pkill -x http-server.elf 2>/dev/null; sudo pkill -x dpdk-ctrl.elf 2>/dev/null; for p in 0 1 2 3; do tmux kill-session -t hs\$p 2>/dev/null; done; tmux kill-session -t dc$N 2>/dev/null; true" >/dev/null 2>&1 & done; wait
  ssh sw1 'for s in sw bft swset pktgen; do tmux kill-session -t $s 2>/dev/null; done; sudo pkill -x bf_switchd 2>/dev/null; sleep 3; tmux new-session -d -s baseline "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_switchd.sh -p port_forward > /tmp/ae-baseline.log 2>&1"' >/dev/null 2>&1
  sleep 50
  ssh sw1 'tmux new-session -d -s blcfg "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /home/singtel/inho/Capybara/capybara/p4/port_forward/port_forward.py > /tmp/ae-blcfg.log 2>&1"' >/dev/null 2>&1
  step "Cleanup done (switch back on port_forward baseline)"
}
trap cleanup EXIT
# Deadman watchdog: if a dropped SSH / hard kill prevents the EXIT trap from
# running during this ~20-60 min sweep, force-clean the cluster after the TTL so
# the next figure starts from a clean baseline. cleanup() (above) disarms it.
bash ~/capybara-AE-runs/arm_watchdog.sh 5400 >/dev/null 2>&1

switch_config(){   # port_add -> setup -> pktgen (switchd must already be up)
  ssh sw1 'cp /home/singtel/inho/fig7-frozen-sw/port_add.py /tmp/ae-port_add.py; tmux kill-session -t bft 2>/dev/null; tmux new-session -d -s bft "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /tmp/ae-port_add.py > /tmp/ae-bft.log 2>&1"'
  sleep 25
  ssh sw1 'tmux kill-session -t bft 2>/dev/null; tmux kill-session -t swset 2>/dev/null; tmux new-session -d -s swset "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /home/singtel/inho/Capybara/capybara/p4/switch_fe/main_eval_setup.py > /tmp/ae-swset.log 2>&1"'
  sleep 30
  ssh sw1 'tmux kill-session -t swset 2>/dev/null; tmux kill-session -t pktgen 2>/dev/null; tmux new-session -d -s pktgen "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_pd_rpc.py -d asic /home/singtel/inho/Capybara/capybara/p4/switch_fe/main_eval_pktgen_timer.py -i > /tmp/ae-pktgen.log 2>&1"'
  sleep 15
}

# ---------------- preflight ----------------
step "Preflight: connectivity node6/8/9/10 + sw1"
for N in 6 8 9 10; do ssh -o ConnectTimeout=5 node$N true >/dev/null 2>&1 || { echo "FATAL: node$N unreachable"; exit 1; }; done
ssh -o ConnectTimeout=5 sw1 true >/dev/null 2>&1 || { echo "FATAL: sw1 unreachable"; exit 1; }
mkdir -p $D
if [ "$RESUME" = "resume" ]; then
  step "Resume mode: completed runs in $(basename $RES) will be reused"
else
  if [ -s "$RES" ]; then
    PREV=$D/fig7_results.$(date +%Y%m%d-%H%M%S).prev.txt
    mv "$RES" "$PREV"
    step "Archived previous dataset -> $(basename $PREV); measuring from scratch"
  fi
fi

# ---------------- switch bring-up ----------------
step "Switch: starting main_eval P4 program (takes ~60s)"
ssh sw1 'for s in sw bft swset pktgen baseline blcfg; do tmux kill-session -t $s 2>/dev/null; done; sudo pkill -x bf_switchd 2>/dev/null; true'
sleep 3
ssh sw1 'rm -f /tmp/ae-switchd.log; tmux new-session -d -s sw "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_switchd.sh -p main_eval > /tmp/ae-switchd.log 2>&1"'
for i in $(seq 1 30); do ssh sw1 'grep -q "bfruntime gRPC server started" /tmp/ae-switchd.log 2>/dev/null' && break; sleep 3; done
ssh sw1 'pgrep -x bf_switchd >/dev/null' || { echo "FATAL: bf_switchd did not start — see sw1:/tmp/ae-switchd.log"; exit 1; }
sleep 5
step "Switch: ports + tables + pktgen (~70s)"
switch_config

# ---------------- iokerneld ----------------
step "Clients: starting iokerneld on node7 + node6"
tmux kill-session -t iok7 2>/dev/null; sudo pkill -x iokerneld 2>/dev/null; sleep 1
tmux new-session -d -s iok7 "cd /homes/inho/Capybara/caladan && sudo ./iokerneld ias nicpci 0000:31:00.1 nobw > /tmp/ae-iok7.log 2>&1"
ssh node6 "tmux kill-session -t iok6 2>/dev/null; sudo pkill -x iokerneld 2>/dev/null; sleep 1; tmux new-session -d -s iok6 \"cd /homes/inho/Capybara/caladan-n6 && sudo ./iokerneld ias nicpci 0000:b3:00.0 nobw > /tmp/ae-iok6.log 2>&1\"" >/dev/null 2>&1
sleep 6
pgrep -x iokerneld >/dev/null || { echo "FATAL: iokerneld failed on node7 — see /tmp/ae-iok7.log"; exit 1; }
ssh node6 "pgrep -x iokerneld >/dev/null" || { echo "FATAL: iokerneld failed on node6 — see node6:/tmp/ae-iok6.log"; exit 1; }

# ---------------- pilot (validates the whole datapath) ----------------
step "Pilot run (validates switch + servers + clients end-to-end)"
if ! bash $D/run_one.sh LWRR 0 pilot; then
  step "Pilot failed — re-running switch table config once (known-flaky bfshell) and retrying"
  switch_config
  bash $D/run_one.sh LWRR 0 pilot || { echo "FATAL: pilot failed twice. Check sw1:/tmp/ae-{bft,swset,pktgen}.log and /tmp/ae-hs8_0.log on node8."; exit 1; }
fi
sed -i '/,pilot,/d' $RES   # pilot lines are not part of the dataset

# ---------------- sweep ----------------
TOTAL=$((RUNS*8)); N_DONE=0
for COND in LWRR CAPY; do
  for Z in 0 0.9 1.0 1.2; do
    HAVE=$(grep -c "^$COND,$Z," $RES 2>/dev/null || true); HAVE=${HAVE:-0}
    [ "$HAVE" -gt 0 ] && step "  reusing $HAVE existing run(s) for $COND z=$Z"
    for R in $(seq 1 $RUNS); do
      if [ "$R" -le "$HAVE" ]; then continue; fi
      OK=0
      for try in 1 2; do bash $D/run_one.sh $COND $Z $R && { OK=1; break; }; step "run failed (try $try) — retrying"; sleep 3; done
      [ $OK = 1 ] || echo "$COND,$Z,$R,FAILED" >> $RES
    done
    N_DONE=$((N_DONE+RUNS))
    step "progress: $N_DONE/$TOTAL cells done ($COND z=$Z complete)"
  done
done

# ---------------- plot ----------------
step "Generating figure"
python3 /homes/sigcomm26ae/capybara-AE-runs/paperplot/paper_style.py fig7 $RES $D/fig7_reproduction || { echo "plot failed — results are in $RES"; exit 1; }
step "DONE. Figure: $D/fig7_reproduction.png (+ .pdf), raw data: $RES"
