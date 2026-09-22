#!/bin/bash
# Bring up the era switch program + L7 table state for capy-proxy/proxy-server.
set -u
step(){ echo "[$(date +%H:%M:%S)] $*"; }
step "switch: capybara_switch_fe_fig11"
ssh sw1 'for s in sw bft swset swov pktgen baseline blcfg; do tmux kill-session -t $s 2>/dev/null; done; sudo pkill -x bf_switchd 2>/dev/null; true' >/dev/null 2>&1
sleep 3
ssh sw1 'rm -f /tmp/ae-switchd.log; tmux new-session -d -s sw "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_switchd.sh -p capybara_switch_fe_fig11 > /tmp/ae-switchd.log 2>&1"' >/dev/null 2>&1
for i in $(seq 1 30); do ssh sw1 'grep -q "bfruntime gRPC server started" /tmp/ae-switchd.log 2>/dev/null' && break; sleep 3; done
ssh sw1 'pgrep -x bf_switchd >/dev/null' || { echo "FATAL switchd"; exit 1; }
sleep 5
step "ports + tables + overlay"
ssh sw1 'cp /home/singtel/inho/fig10/port_add_jumbo.py /tmp/ae-port_add.py; tmux new-session -d -s bft "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /tmp/ae-port_add.py > /tmp/ae-bft.log 2>&1"' >/dev/null 2>&1
sleep 25
ssh sw1 'tmux kill-session -t bft 2>/dev/null; tmux new-session -d -s swset "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /home/singtel/inho/fig11/setup_fig11.py > /tmp/ae-swset.log 2>&1"' >/dev/null 2>&1
sleep 25
ssh sw1 'tmux kill-session -t swset 2>/dev/null; tmux new-session -d -s swov "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /home/singtel/inho/fig11/overlay_l7.py > /tmp/ae-swov.log 2>&1"' >/dev/null 2>&1
sleep 20
ssh sw1 'tmux kill-session -t swov 2>/dev/null; grep -c L7_OVERLAY_DONE /tmp/ae-swov.log; grep -c Traceback /tmp/ae-swset.log /tmp/ae-swov.log | paste -sd" "' 2>/dev/null
ssh sw1 'tmux new-session -d -s swov2 "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /home/singtel/inho/fig11/overlay_minport.py > /tmp/ae-swov2.log 2>&1"' >/dev/null 2>&1
sleep 18
ssh sw1 'tmux kill-session -t swov2 2>/dev/null; grep -c MINPORT_DONE /tmp/ae-swov2.log'
step "bring-up done"
