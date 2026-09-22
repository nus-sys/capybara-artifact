#!/bin/bash
# Fig-10 bring-up: main_eval_fig10 P4 (12 backends, static port%12 binding, min-rps
# migration targeting) + 1ms pktgen + iokerneld on node5/6/7.
set -u
step(){ echo "[$(date +%H:%M:%S)] $*"; }

step "switch: main_eval_fig10"
ssh sw1 'for s in sw bft swset pktgen baseline blcfg; do tmux kill-session -t $s 2>/dev/null; done; sudo pkill -x bf_switchd 2>/dev/null; true'
sleep 3
ssh sw1 'rm -f /tmp/ae-switchd.log; tmux new-session -d -s sw "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_switchd.sh -p main_eval_fig10 > /tmp/ae-switchd.log 2>&1"'
for i in $(seq 1 30); do ssh sw1 'grep -q "bfruntime gRPC server started" /tmp/ae-switchd.log 2>/dev/null' && break; sleep 3; done
ssh sw1 'pgrep -x bf_switchd >/dev/null' || { echo "FATAL: switchd failed"; exit 1; }
sleep 5
ssh sw1 'cp /home/singtel/inho/fig10/port_add_jumbo.py /tmp/ae-port_add.py; tmux new-session -d -s bft "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /tmp/ae-port_add.py > /tmp/ae-bft.log 2>&1"'
sleep 25
SWSETUP=${SWSETUP:-\/home/singtel/inho/fig10/main_eval_fig10_setup.py}
ssh sw1 "tmux kill-session -t bft 2>/dev/null; tmux new-session -d -s swset \"source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b $SWSETUP > /tmp/ae-swset.log 2>&1\"" 
sleep 40
ssh sw1 'tmux kill-session -t swset 2>/dev/null; tmux kill-session -t pktgen 2>/dev/null; tmux new-session -d -s pktgen "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_pd_rpc-9.2.0.py -d asic /home/singtel/inho/fig8/main_eval_pktgen_timer_1ms.py -i > /tmp/ae-pktgen.log 2>&1"'
sleep 15

step "node7 hugepages: node0 pool -> 2560 pages (iokerneld + client both fit; cleanup restores 1568)"
echo 2560 | sudo tee /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages >/dev/null
[ "$(cat /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages)" = "2560" ] || echo "WARN: node0 hugepage raise incomplete ($(cat /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages))"

step "client data-NIC MTU -> 9216 (jumbo responses >= 4 KB need it; at the default 1500 the port drops them and that client records 0)"
sudo ip link set $(ls /sys/bus/pci/devices/0000:31:00.1/net/) mtu 9216 2>/dev/null
for CN in 5 6; do ssh node$CN "sudo ip link set \$(ls /sys/bus/pci/devices/0000:b3:00.0/net/) mtu 9216 2>/dev/null; true" >/dev/null 2>&1; done
M7=$(cat /sys/bus/pci/devices/0000:31:00.1/net/*/mtu 2>/dev/null)
M6=$(ssh node6 "cat /sys/bus/pci/devices/0000:b3:00.0/net/*/mtu" 2>/dev/null)
M5=$(ssh node5 "cat /sys/bus/pci/devices/0000:b3:00.0/net/*/mtu" 2>/dev/null)
[ "$M7$M6$M5" = "921692169216" ] || echo "WARN: client data-NIC MTU not 9216 everywhere (n7=$M7 n6=$M6 n5=$M5) — sizes >= 4 KB will record 0 for that client"

step "iokerneld on node7/6/5"
tmux kill-session -t iok7 2>/dev/null; sudo pkill -x iokerneld 2>/dev/null; sleep 1
tmux new-session -d -s iok7 "cd /homes/inho/Capybara/caladan-fig8 && sudo ./iokerneld ias nicpci 0000:31:00.1 nobw > /tmp/ae-iok7.log 2>&1"
ssh node6 "tmux kill-session -t iok6 2>/dev/null; sudo pkill -x iokerneld 2>/dev/null; sleep 1; tmux new-session -d -s iok6 \"cd /homes/inho/Capybara/caladan-fig8-n6 && sudo ./iokerneld ias nicpci 0000:b3:00.0 nobw > /tmp/ae-iok6.log 2>&1\"" >/dev/null 2>&1
ssh node5 "tmux kill-session -t iok5 2>/dev/null; sudo pkill -x iokerneld 2>/dev/null; sleep 1; sudo mknod /dev/ksched c 280 0 2>/dev/null; sudo chmod uga+rwx /dev/ksched 2>/dev/null; tmux new-session -d -s iok5 \"cd /homes/inho/Capybara/caladan-fig8-n6 && sudo LD_LIBRARY_PATH=\\/homes/inho/lib ./iokerneld ias nicpci 0000:b3:00.0 nobw > /tmp/ae-iok5.log 2>&1\"" >/dev/null 2>&1
sleep 8
for chk in "pgrep -x iokerneld" "ssh node6 pgrep -x iokerneld" "ssh node5 pgrep -x iokerneld"; do
  $chk >/dev/null 2>&1 || { echo "FATAL: iokerneld missing ($chk)"; exit 1; }
done
step "bring-up done"
