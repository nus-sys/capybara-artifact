#!/bin/bash
# Fig-8 switch bring-up: main_eval P4 + FIG8 table setup (2 node9 backends) + 1ms pktgen.
# Also starts iokerneld on node7. Original switch scripts untouched (fig8 variants in sw1:/home/singtel/inho/fig8/).
set -u
step(){ echo "[$(date +%H:%M:%S)] $*"; }

step "client node7: restore reboot-cleared prerequisites (ksched, sysctls, hugepages, NIC)"
bash ~/capybara-AE-runs/prepare_nodes.sh 7 || { echo "FATAL: node7 not ready (see above)"; exit 1; }

step "switch: main_eval + fig8 tables + 1ms pktgen"
ssh sw1 'for s in sw bft swset pktgen baseline blcfg; do tmux kill-session -t $s 2>/dev/null; done; sudo pkill -x bf_switchd 2>/dev/null; true'
sleep 3
ssh sw1 'rm -f /tmp/ae-switchd.log; tmux new-session -d -s sw "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_switchd.sh -p main_eval_fig8 > /tmp/ae-switchd.log 2>&1"'
for i in $(seq 1 30); do ssh sw1 'grep -q "bfruntime gRPC server started" /tmp/ae-switchd.log 2>/dev/null' && break; sleep 3; done
ssh sw1 'pgrep -x bf_switchd >/dev/null' || { echo "FATAL: switchd failed"; exit 1; }
sleep 5
ssh sw1 'cp /home/singtel/inho/fig7-frozen-sw/port_add.py /tmp/ae-port_add.py; tmux new-session -d -s bft "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /tmp/ae-port_add.py > /tmp/ae-bft.log 2>&1"'
sleep 25
ssh sw1 'tmux kill-session -t bft 2>/dev/null; tmux new-session -d -s swset "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /home/singtel/inho/fig8/main_eval_fig8_setup.py > /tmp/ae-swset.log 2>&1"'
sleep 30
ssh sw1 'tmux kill-session -t swset 2>/dev/null; tmux kill-session -t pktgen 2>/dev/null; tmux new-session -d -s pktgen "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_pd_rpc-9.2.0.py -d asic /home/singtel/inho/fig8/main_eval_pktgen_timer_1ms.py -i > /tmp/ae-pktgen.log 2>&1"'
sleep 15

step "iokerneld on node7"
tmux kill-session -t iok7 2>/dev/null; sudo pkill -x iokerneld 2>/dev/null; sleep 1
tmux new-session -d -s iok7 "cd /homes/inho/Capybara/caladan && sudo ./iokerneld ias nicpci 0000:31:00.1 nobw > /tmp/ae-iok7.log 2>&1"
sleep 6
pgrep -x iokerneld >/dev/null || { echo "FATAL: iokerneld failed"; exit 1; }
step "bring-up done"
