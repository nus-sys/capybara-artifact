#!/bin/bash
# Fig-13 (Capybara-SW column) bring-up.
#   - the Tofino runs the plain L2 program (endhost_switch): every frame that does not
#     come from node7 is sent to node7, frames from node7 are L2-forwarded by MAC
#   - node7 hosts Capybara's software switch (its NIC is therefore not a client port)
#   - node5/node6 are the load generators (fresh caladan iokernel each)
#   - node8/9/10: a dpdk-ctrl primary per node is started by every measurement; the
#     backends attach to it
set -u
step(){ echo "[$(date +%H:%M:%S)] $*"; }
BE=/homes/inho/Capybara/capybara-fig13be          # backend tree (Fig 10 server, no reply rewriting)
CAL=/homes/inho/Capybara/caladan-fig8-n6          # client iokernel tree (node5/6)

step "clients node5/6: prerequisites"
bash ~/capybara-AE-runs/prepare_nodes.sh 7 6 5 || { echo "FATAL: a client node is not ready"; exit 1; }

step "switch: endhost_switch (plain L2 forwarding) + ports"
bash ~/capybara-AE-runs/switch_restart.sh endhost_switch || { echo "FATAL: switchd failed"; exit 1; }
for i in $(seq 1 30); do ssh sw1 'grep -q "bfruntime gRPC server started" /tmp/ae-switchd.log 2>/dev/null' && break; sleep 3; done
ssh sw1 'pgrep -x bf_switchd >/dev/null' || { echo "FATAL: switchd failed"; exit 1; }
sleep 5
ssh sw1 'sudo rm -f /tmp/ae-swset.log; tmux new-session -d -s swset "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /home/singtel/inho/Capybara/capybara/p4/endhost_switch/endhost_switch.py > /tmp/ae-swset.log 2>&1"'
for i in $(seq 1 30); do ssh sw1 'tmux has-session -t swset 2>/dev/null' || break; sleep 3; done
echo "  switch setup tracebacks: $(ssh sw1 'grep -c Traceback /tmp/ae-swset.log' 2>/dev/null)"

step "node7: free the NIC for the software switch (no iokernel), hugepages node0 -> 2560"
tmux kill-session -t iok7 2>/dev/null; sudo pkill -x iokerneld 2>/dev/null
tmux kill-session -t sw7 2>/dev/null; sudo pkill -x capybara-switch 2>/dev/null
sleep 1; sudo rm -rf /var/run/dpdk/rte 2>/dev/null
echo 2560 | sudo tee /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages >/dev/null

step "iokerneld on node5/6 (clients; restarted again before every measurement)"
for n in 5 6; do bash ~/capybara-AE-runs/restart_client_iokernel.sh $n $CAL || { echo "FATAL: iokerneld failed on node$n"; exit 1; }; done

step "server nodes: nothing left from a previous experiment (dpdk-ctrl is started per measurement)"
for M in 8 9 10; do ssh node$M "sudo pkill -INT -x http-server.elf 2>/dev/null; sleep 1; sudo pkill -x http-server.elf 2>/dev/null; sudo pkill -x dpdk-ctrl.elf 2>/dev/null; for s in dc$M hs0 hs1 hs2 hs3 f8s0 f8s1 f15s0 f15s1; do tmux kill-session -t \$s 2>/dev/null; done; sleep 1; sudo rm -rf /var/run/dpdk/rte 2>/dev/null; true" >/dev/null 2>&1 & done; wait
step "bring-up done"
