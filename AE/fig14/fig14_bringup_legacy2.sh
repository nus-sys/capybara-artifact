#!/bin/bash
# Switch bring-up for the migration-latency experiment, using the program the
# paper's driver actually configured for it: capybara_switch_fe_src_rewriting_by_server.
# Its setup script already carries the experiment's backend layout
# (backend 0 = 10.0.1.8:10000, backend 1 = 10.0.1.9:10000), and the program
# generates no RPS signals, so the stack's built-in migration targeting stands.
set -u
step(){ echo "[$(date +%H:%M:%S)] $*"; }

step "switch: capybara_switch_fe_src_rewriting_by_server"
ssh sw1 'for s in sw bft swset pktgen baseline blcfg; do tmux kill-session -t $s 2>/dev/null; done; sudo pkill -x bf_switchd 2>/dev/null; true' >/dev/null 2>&1
sleep 3
ssh sw1 'rm -f /tmp/ae-switchd.log; tmux new-session -d -s sw "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_switchd.sh -p capybara_switch_fe_src_rewriting_by_server > /tmp/ae-switchd.log 2>&1"' >/dev/null 2>&1
for i in $(seq 1 30); do ssh sw1 'grep -q "bfruntime gRPC server started" /tmp/ae-switchd.log 2>/dev/null' && break; sleep 3; done
ssh sw1 'pgrep -x bf_switchd >/dev/null' || { echo "FATAL: bf_switchd did not start"; exit 1; }
sleep 5

step "switch: ports"
ssh sw1 'cp /home/singtel/inho/fig7-frozen-sw/port_add.py /tmp/ae-port_add.py; tmux kill-session -t bft 2>/dev/null; tmux new-session -d -s bft "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /tmp/ae-port_add.py > /tmp/ae-bft.log 2>&1"' >/dev/null 2>&1
sleep 25

step "switch: tables (the driver's own setup script)"
ssh sw1 'tmux kill-session -t bft 2>/dev/null; tmux kill-session -t swset 2>/dev/null; tmux new-session -d -s swset "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /home/singtel/inho/Capybara/capybara/p4/switch_fe/capybara_switch_fe_src_rewriting_by_server_setup.py > /tmp/ae-swset.log 2>&1"' >/dev/null 2>&1
sleep 30
ssh sw1 'tmux kill-session -t swset 2>/dev/null; grep -cE "Error|error" /tmp/ae-swset.log' 2>/dev/null | xargs echo "  setup errors:"

step "bring-up done"
