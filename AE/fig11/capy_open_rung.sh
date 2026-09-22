#!/bin/bash
# One open-loop rung against capy-proxy: fresh dpdk-ctrl + FE + BEs, then a
# single-pps caladan run. Everything restarts every rung (a long-lived
# dpdk-ctrl primary wedges secondary attach after repeated server restarts).
# The curl sanity check runs with iokerneld STOPPED: caladan directpath steals
# inbound frames on node7 (rx_phy grows, tcpdump sees nothing), so kernel curl
# is only trustworthy without it; run_fig11_open.sh restarts iokerneld after.
# Assumes fig11_bringup_capy2.sh <NB> was already run for this NB.
# usage: capy_open_rung.sh <NB> <pps> [runtime]
set -u
NB=$1; PPS=$2; RT=${3:-10}
T=/homes/inho/Capybara/capybara-fig11
for N in 8 9; do ssh node$N "sudo pkill -INT -x capy-proxy-fe.e 2>/dev/null; sudo pkill -INT -x capy-proxy-be.e 2>/dev/null; sleep 1; sudo pkill -9 -x capy-proxy-fe.e 2>/dev/null; sudo pkill -9 -x capy-proxy-be.e 2>/dev/null; sudo pkill -x dpdk-ctrl.elf 2>/dev/null; tmux kill-server 2>/dev/null; sudo rm -rf /var/run/dpdk/rte 2>/dev/null; true" >/dev/null 2>&1; done
sleep 2
for N in 8 9; do ssh node$N "tmux new-session -d -s dc$N \"cd $T && make PREFIX=/homes/inho dpdk-ctrl-node$N > /tmp/ae-dc$N.log 2>&1\"" >/dev/null 2>&1; done
sleep 22
ssh node8 "tmux new-session -d -s fe \"cd $T && sudo -E env CORE_ID=1 NUM_BE=$NB CONFIG_PATH=$T/scripts/config/node8_config.yaml MTU=9000 MSS=8960 NUM_CORES=4 USE_JUMBO=1 LIBOS=catnip DATA_SIZE=131072 LD_LIBRARY_PATH=\\/homes/inho/lib:\\/homes/inho/lib/x86_64-linux-gnu numactl -m0 timeout 900 $T/bin/examples/rust/capy-proxy-fe.elf 10.0.1.8:10000 > /tmp/ae-cpfe.log 2>&1\"" >/dev/null 2>&1
sleep 2
start_bes(){
for j in $(seq 0 $((NB-1))); do
  ssh node9 "tmux new-session -d -s be$j \"cd $T && sudo -E env CORE_ID=$((j+1)) NUM_BE=$NB CONFIG_PATH=$T/scripts/config/node9_config.yaml MTU=9000 MSS=8960 NUM_CORES=4 USE_JUMBO=1 LIBOS=catnip DATA_SIZE=131072 LD_LIBRARY_PATH=\\/homes/inho/lib:\\/homes/inho/lib/x86_64-linux-gnu numactl -m0 timeout 900 $T/bin/examples/rust/capy-proxy-be.elf 10.0.1.9:1000$j 10.0.1.8:10000 > /tmp/ae-cpbe$j.log 2>&1\"" >/dev/null 2>&1
done
}
start_bes
sleep 5
# A backend that dies at start still passes the curl sanity below (the FE
# serves through the live ones) but caps throughput at live/NB of the
# recorded value. Verify all $NB backends are up; restart the set if not.
for chk in 1 2 3; do
  NBE=$(ssh node9 "pgrep -xc capy-proxy-be.e" 2>/dev/null); NBE=${NBE:-0}
  [ "$NBE" = "$NB" ] && break
  if [ "$chk" = "3" ]; then
    echo "RES open capy-nb$NB pps=$PPS SANITY-FAIL (be=$NBE/$NB)" | tee -a ~/capybara-AE-runs/fig11/results_open.txt
    exit 1
  fi
  ssh node9 "sudo pkill -INT -x capy-proxy-be.e 2>/dev/null; sleep 1; sudo pkill -9 -x capy-proxy-be.e 2>/dev/null; true" >/dev/null 2>&1
  sleep 2
  start_bes
  sleep 5
done
tmux kill-session -t iok7 2>/dev/null; sudo pkill -x iokerneld 2>/dev/null; sleep 2
sudo ip route replace 10.0.1.8/32 dev ens85f1np1 advmss 8960 2>/dev/null
CODE=$(timeout 10 curl -s -o /dev/null -w "%{http_code}" http://10.0.1.8:55555/get)
if [ "$CODE" != "200" ]; then
  echo "RES open capy-nb$NB pps=$PPS SANITY-FAIL" | tee -a ~/capybara-AE-runs/fig11/results_open.txt
  exit 1
fi
bash ~/capybara-AE-runs/fig11/run_fig11_open.sh capy-nb$NB 10.0.1.8:55555 "$PPS" $RT
