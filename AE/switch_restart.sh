#!/bin/bash
# Restart the Tofino switch daemon on sw1 with a given P4 program, robustly.
#
#   bash ~/capybara-AE-runs/switch_restart.sh <program> [tmux-session] [log]
#     program       e.g. port_forward, main_eval_fig8, main_eval_fig10, prism, endhost_switch
#     tmux-session  default "sw"              (the baseline uses "baseline")
#     log           default /tmp/ae-switchd.log (the baseline uses /tmp/ae-baseline.log)
#
# Exit 0 once the program's bfruntime gRPC server is up; exit 1 otherwise. Why this
# exists: the previous bf_switchd holds the bf_kpkt kernel device for several seconds
# after SIGTERM. A new bf_switchd started in that window dies with "kernel packet module
# master initialization failed" (dmesg: "error registering LLD tx callback") and leaves
# the switch with no program at all (seen 2026-10-04 13:10 in a reviewer run). So: wait
# for the old daemon to be gone, start, and if it still fails, reload bf_kpkt and retry.
set -u
PROG=$1; SESS=${2:-sw}; LOG=${3:-/tmp/ae-switchd.log}
ssh -o ConnectTimeout=10 sw1 "bash -s" "$PROG" "$SESS" "$LOG" <<'EOF'
PROG=$1; SESS=$2; LOG=$3
SDE=/home/singtel/bf-sde-9.4.0
for s in sw bft swset swov swov2 pktgen baseline blcfg rdr p4b bx insp pcnt; do tmux kill-session -t $s 2>/dev/null; done
sudo pkill -x bf_switchd 2>/dev/null
for i in $(seq 1 40); do pgrep -x bf_switchd >/dev/null || break; sleep 1; done
if pgrep -x bf_switchd >/dev/null; then sudo pkill -9 -x bf_switchd 2>/dev/null; sleep 4; fi
for attempt in 1 2; do
  sudo rm -f "$LOG" 2>/dev/null
  tmux new-session -d -s "$SESS" "source /home/singtel/tools/set_sde.bash; $SDE/run_switchd.sh -p $PROG > $LOG 2>&1"
  for i in $(seq 1 60); do
    grep -q "bfruntime gRPC server started" "$LOG" 2>/dev/null && exit 0
    grep -q "kernel packet module master initialization failed" "$LOG" 2>/dev/null && break
    pgrep -x bf_switchd >/dev/null || break
    sleep 2
  done
  echo "switchd ($PROG) attempt $attempt failed: $(grep -aE 'ERROR|rror' "$LOG" 2>/dev/null | tail -1 | cut -c1-120)"
  tmux kill-session -t "$SESS" 2>/dev/null; sudo pkill -9 -x bf_switchd 2>/dev/null; sleep 4
  echo "reloading the bf_kpkt kernel module"
  sudo $SDE/install/bin/bf_kpkt_mod_unload $SDE/install >/dev/null 2>&1; sleep 2
  sudo $SDE/install/bin/bf_kpkt_mod_load $SDE/install >/dev/null 2>&1; sleep 3
done
echo "switchd ($PROG) did not come up; see sw1:$LOG"
exit 1
EOF
