#!/bin/bash
# Switch bring-up for the Prism experiments: the prism program IS the handoff
# agent (it parses the psw request packets addressed to 10.0.1.7:18080 and
# updates its ownership tables in the data plane).
set -u
step(){ echo "[$(date +%H:%M:%S)] $*"; }
step "switch: prism program"
ssh sw1 'for s in sw bft swset pktgen baseline blcfg; do tmux kill-session -t $s 2>/dev/null; done; sudo pkill -x bf_switchd 2>/dev/null; true' >/dev/null 2>&1
sleep 3
ssh sw1 'rm -f /tmp/ae-switchd.log; tmux new-session -d -s sw "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_switchd.sh -p prism > /tmp/ae-switchd.log 2>&1"' >/dev/null 2>&1
for i in $(seq 1 30); do ssh sw1 'grep -q "bfruntime gRPC server started" /tmp/ae-switchd.log 2>/dev/null' && break; sleep 3; done
ssh sw1 'pgrep -x bf_switchd >/dev/null' || { echo "FATAL: switchd"; exit 1; }
sleep 5
step "switch: ports"
ssh sw1 'cp /home/singtel/inho/fig7-frozen-sw/port_add.py /tmp/ae-port_add.py; tmux kill-session -t bft 2>/dev/null; tmux new-session -d -s bft "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /tmp/ae-port_add.py > /tmp/ae-bft.log 2>&1"' >/dev/null 2>&1
sleep 25
step "switch: prism tables"
ssh sw1 'tmux kill-session -t bft 2>/dev/null; tmux kill-session -t swset 2>/dev/null; tmux new-session -d -s swset "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /home/singtel/inho/Capybara/capybara/p4/prism/prism_setup.py > /tmp/ae-swset.log 2>&1"' >/dev/null 2>&1
sleep 25
ssh sw1 'tmux kill-session -t swset 2>/dev/null; grep -ciE "error" /tmp/ae-swset.log' 2>/dev/null | xargs echo "  setup errors:"
step "bring-up done"
