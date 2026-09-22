#!/bin/bash
# Switch bring-up for the migration-latency experiment.
# Same data plane as Fig. 8, but the table setup places one backend on node8 and
# one on node9, both on the frontend port, and narrows the load-signal multicast
# to those two nodes.
set -u
step(){ echo "[$(date +%H:%M:%S)] $*"; }

step "switch: main_eval_fig8 program"
ssh sw1 'for s in sw bft swset pktgen baseline blcfg; do tmux kill-session -t $s 2>/dev/null; done; sudo pkill -x bf_switchd 2>/dev/null; true' >/dev/null 2>&1
sleep 3
ssh sw1 'rm -f /tmp/ae-switchd.log; tmux new-session -d -s sw "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_switchd.sh -p main_eval_fig8 > /tmp/ae-switchd.log 2>&1"' >/dev/null 2>&1
for i in $(seq 1 30); do ssh sw1 'grep -q "bfruntime gRPC server started" /tmp/ae-switchd.log 2>/dev/null' && break; sleep 3; done
ssh sw1 'pgrep -x bf_switchd >/dev/null' || { echo "FATAL: bf_switchd did not start"; exit 1; }
sleep 5

step "switch: ports"
ssh sw1 'cp /home/singtel/inho/fig7-frozen-sw/port_add.py /tmp/ae-port_add.py; tmux kill-session -t bft 2>/dev/null; tmux new-session -d -s bft "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /tmp/ae-port_add.py > /tmp/ae-bft.log 2>&1"' >/dev/null 2>&1
sleep 25

step "switch: two-backend tables"
ssh sw1 'tmux kill-session -t bft 2>/dev/null; tmux kill-session -t swset 2>/dev/null; tmux new-session -d -s swset "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /home/singtel/inho/fig14/main_eval_fig14_setup.py > /tmp/ae-swset.log 2>&1"' >/dev/null 2>&1
sleep 30

step "switch: load-signal packet generator"
ssh sw1 'tmux kill-session -t swset 2>/dev/null; tmux kill-session -t pktgen 2>/dev/null; tmux new-session -d -s pktgen "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_pd_rpc-9.2.0.py -d asic /home/singtel/inho/fig8/main_eval_pktgen_timer_1ms.py -i > /tmp/ae-pktgen.log 2>&1"' >/dev/null 2>&1
sleep 15

step "bring-up done"
