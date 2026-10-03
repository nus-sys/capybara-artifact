#!/bin/bash
# Fig-13 (Capybara-SW column) bring-up: the switch runs the plain L2 program
# (endhost_switch), the load balancer is Capybara's software switch on node8.
# Also prepares node7 as the client (hugepages, jumbo MTU, iokerneld).
set -u
step(){ echo "[$(date +%H:%M:%S)] $*"; }
step "client node7: prerequisites"
bash ~/capybara-AE-runs/prepare_nodes.sh 7 || { echo "FATAL: node7 not ready"; exit 1; }
step "switch: endhost_switch (plain L2 forwarding) + ports"
ssh sw1 'for s in sw bft swset swov pktgen baseline blcfg; do tmux kill-session -t $s 2>/dev/null; done; sudo pkill -x bf_switchd 2>/dev/null; true' >/dev/null 2>&1
sleep 3
ssh sw1 'sudo rm -f /tmp/ae-switchd.log; tmux new-session -d -s sw "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_switchd.sh -p endhost_switch > /tmp/ae-switchd.log 2>&1"'
for i in $(seq 1 30); do ssh sw1 'grep -q "bfruntime gRPC server started" /tmp/ae-switchd.log 2>/dev/null' && break; sleep 3; done
ssh sw1 'pgrep -x bf_switchd >/dev/null' || { echo "FATAL: switchd failed"; exit 1; }
sleep 5
ssh sw1 'sudo rm -f /tmp/ae-swset.log; tmux new-session -d -s swset "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /home/singtel/inho/Capybara/capybara/p4/endhost_switch/endhost_switch.py > /tmp/ae-swset.log 2>&1"'
for i in $(seq 1 30); do ssh sw1 'tmux has-session -t swset 2>/dev/null' || break; sleep 3; done
echo "  switch setup tracebacks: $(ssh sw1 'grep -c Traceback /tmp/ae-swset.log' 2>/dev/null)"
step "node7: hugepages (node0 -> 2560), client port MTU 9216 (set before the iokernel attaches)"
echo 2560 | sudo tee /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages >/dev/null
sudo ip link set $(ls /sys/bus/pci/devices/0000:31:00.1/net/) mtu 9216 2>/dev/null
step "iokerneld on node7"
tmux kill-session -t iok7 2>/dev/null; sudo pkill -x iokerneld 2>/dev/null; sleep 1
tmux new-session -d -s iok7 "cd /homes/inho/Capybara/caladan-fig8 && sudo ./iokerneld ias nicpci 0000:31:00.1 nobw > /tmp/ae-iok7.log 2>&1"
sleep 8
pgrep -x iokerneld >/dev/null || { echo "FATAL: iokerneld failed on node7"; exit 1; }
step "bring-up done"
