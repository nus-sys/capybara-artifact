#!/bin/bash
# One-command full cluster cleanup for Capybara AE experiments.
# Kills every experiment process on all nodes and restores the switch baseline.
# Safe to run at any time, from anywhere (runs on node7).
step(){ echo "[$(date +%H:%M:%S)] $*"; }

step "clients (node5/6/7)"
for s in cl7 sf7 f8c f9c ab cal sweep pilot; do tmux kill-session -t $s 2>/dev/null; done
sudo pkill -x synthetic 2>/dev/null
for n in 5 6; do
  ssh -o ConnectTimeout=5 node$n "for s in cl5 cl6 sf6 cal ab; do tmux kill-session -t \$s 2>/dev/null; done; sudo pkill -x synthetic 2>/dev/null; true" >/dev/null 2>&1
done

step "servers + dpdk-ctrl (node8/9/10)"
for N in 8 9 10; do
  ssh -o ConnectTimeout=5 node$N "sudo pkill -INT -x http-server.elf 2>/dev/null; sudo pkill -INT -x redis-server 2>/dev/null; sleep 1; sudo pkill -x http-server.elf 2>/dev/null; sudo pkill -x redis-server 2>/dev/null; sudo pkill -x dpdk-ctrl.elf 2>/dev/null; for s in hs0 hs1 hs2 hs3 f8s0 f8s1 f9s0 f9s1 dc8 dc9 dc10; do tmux kill-session -t \$s 2>/dev/null; done; true" >/dev/null 2>&1 &
done
wait

step "fig11 L7 binaries (node8/9)"
for N in 8 9; do
  ssh -o ConnectTimeout=5 node$N "sudo pkill -INT -x capy-proxy-fe.e 2>/dev/null; sudo pkill -INT -x capy-proxy-be.e 2>/dev/null; sleep 1; sudo pkill -9 -x capy-proxy-fe.e 2>/dev/null; sudo pkill -9 -x capy-proxy-be.e 2>/dev/null; sudo pkill -INT -x prism-fe.elf 2>/dev/null; sudo pkill -INT -x prism-be-http.e 2>/dev/null; sleep 1; sudo pkill -9 -x prism-fe.elf 2>/dev/null; sudo pkill -9 -x prism-be-http.e 2>/dev/null; for s in fe be0 be1 be2 be3; do tmux kill-session -t $s 2>/dev/null; done; true" >/dev/null 2>&1
done

step "iokerneld (node5/6/7)"
tmux kill-session -t iok7 2>/dev/null; sudo pkill -x iokerneld 2>/dev/null
for n in 5 6; do ssh -o ConnectTimeout=5 node$n "tmux kill-session -t iok$n 2>/dev/null; sudo pkill -x iokerneld 2>/dev/null; true" >/dev/null 2>&1; done

step "node7 hugepages -> boot default (1568)"
sleep 2   # let the killed iokerneld release its hugetlb pool first
echo 1568 | sudo tee /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages >/dev/null 2>&1
[ "$(cat /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages)" = "1568" ] || { sleep 3; echo 1568 | sudo tee /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages >/dev/null 2>&1; }

step "switch -> port_forward baseline"
ssh -o ConnectTimeout=8 sw1 'for s in sw bft swset pktgen p4b bx insp; do tmux kill-session -t $s 2>/dev/null; done; sudo pkill -x bf_switchd 2>/dev/null; sleep 3; tmux new-session -d -s baseline "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_switchd.sh -p port_forward > /tmp/ae-baseline.log 2>&1"' >/dev/null 2>&1
sleep 50
ssh -o ConnectTimeout=8 sw1 'tmux new-session -d -s blcfg "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /home/singtel/inho/Capybara/capybara/p4/port_forward/port_forward.py > /tmp/ae-blcfg.log 2>&1"' >/dev/null 2>&1

# disarm the watchdog (we cleaned up properly)
tmux kill-session -t wdog 2>/dev/null
step "cleanup complete"
