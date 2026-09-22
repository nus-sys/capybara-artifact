#!/bin/bash
# Fig11 closed-loop panel, Capybara-L7 (capy-proxy): one backend count, a wrk
# connection ladder, servers restarted per rung (a collapsed rung wedges them).
# Paper cells were wrk Transfer/sec at DATA_SIZE=131072; CSV value = GB/s * 8.
# usage: run_fig11_capy_closed.sh <NB> "<conn list>" [dur_s]
# output: appends "RES capy closed NB=<n> c=<c> rps=<r> gbps=<g> p99=<l>" lines
#         to ~/capybara-AE-runs/fig11/results_closed_capy.txt
set -u
NB=$1; CONNS=${2:-"30 50 70"}; DUR=${3:-10}
T=/homes/inho/Capybara/capybara-fig11
OUT=~/capybara-AE-runs/fig11/results_closed_capy.txt
DS=131072

bash ~/capybara-AE-runs/fig11/fig11_bringup_capy2.sh $NB >/dev/null 2>&1

start_servers () {
  for N in 8 9; do ssh node$N "sudo pkill -INT -x capy-proxy-fe.e 2>/dev/null; sudo pkill -INT -x capy-proxy-be.e 2>/dev/null; sleep 1; sudo pkill -9 -x capy-proxy-fe.e 2>/dev/null; sudo pkill -9 -x capy-proxy-be.e 2>/dev/null; true" >/dev/null 2>&1; done
  sleep 2
  # dpdk-ctrl only if not already up
  for N in 8 9; do
    ssh node$N "pgrep -x dpdk-ctrl.elf >/dev/null" || {
      ssh node$N "sudo pkill -x dpdk-ctrl.elf 2>/dev/null; sudo rm -rf /var/run/dpdk/rte 2>/dev/null; tmux kill-session -t dc$N 2>/dev/null; tmux new-session -d -s dc$N \"cd $T && make PREFIX=/homes/inho dpdk-ctrl-node$N > /tmp/ae-dc$N.log 2>&1\"" >/dev/null 2>&1
      DPDK_STARTED=1
    }
  done
  [ "${DPDK_STARTED:-0}" = "1" ] && sleep 22
  ssh node8 "tmux kill-session -t fe 2>/dev/null; tmux new-session -d -s fe \"cd $T && sudo -E env CORE_ID=1 NUM_BE=$NB CONFIG_PATH=$T/scripts/config/node8_config.yaml MTU=9000 MSS=8960 NUM_CORES=4 USE_JUMBO=1 LIBOS=catnip DATA_SIZE=$DS LD_LIBRARY_PATH=\\/homes/inho/lib:\\/homes/inho/lib/x86_64-linux-gnu numactl -m0 timeout 900 $T/bin/examples/rust/capy-proxy-fe.elf 10.0.1.8:10000 > /tmp/ae-cpfe.log 2>&1\"" >/dev/null 2>&1
  sleep 2
  for j in $(seq 0 $((NB-1))); do
    ssh node9 "tmux kill-session -t be$j 2>/dev/null; tmux new-session -d -s be$j \"cd $T && sudo -E env CORE_ID=$((j+1)) NUM_BE=$NB CONFIG_PATH=$T/scripts/config/node9_config.yaml MTU=9000 MSS=8960 NUM_CORES=4 USE_JUMBO=1 LIBOS=catnip DATA_SIZE=$DS LD_LIBRARY_PATH=\\/homes/inho/lib:\\/homes/inho/lib/x86_64-linux-gnu numactl -m0 timeout 900 $T/bin/examples/rust/capy-proxy-be.elf 10.0.1.9:1000$j 10.0.1.8:10000 > /tmp/ae-cpbe$j.log 2>&1\"" >/dev/null 2>&1
  done
  sleep 5
}

for C in $CONNS; do
  # up to 3 bring-up attempts; a rung is trusted only when ALL $NB backends and
  # the FE are up AND a request completes. (A single curl can pass with only one
  # live backend because the switch RRs the SYN — that silently halves throughput.)
  OK=0
  for attempt in 1 2 3; do
    start_servers
    sleep $((attempt * 2))
    NBE=$(ssh node9 "pgrep -xc capy-proxy-be.e" 2>/dev/null); NBE=${NBE:-0}
    NFE=$(ssh node8 "pgrep -xc capy-proxy-fe.e" 2>/dev/null); NFE=${NFE:-0}
    sudo ip route replace 10.0.1.8/32 dev ens85f1np1 advmss 8960 2>/dev/null
    CODE=$(timeout 8 curl -s -o /dev/null -w "%{http_code}" http://10.0.1.8:55555/get)
    if [ "$CODE" = "200" ] && [ "$NBE" = "$NB" ] && [ "$NFE" = "1" ]; then OK=1; break; fi
  done
  if [ "$OK" != "1" ]; then
    echo "RES capy closed NB=$NB c=$C SANITY-FAIL (be=$NBE/$NB fe=$NFE code=$CODE)" | tee -a $OUT
    continue
  fi
  W=$(/homes/inho/wrk-tools/wrk/wrk -t$C -c$C -d${DUR}s --latency http://10.0.1.8:55555/get 2>&1)
  RPS=$(echo "$W" | awk "/Requests\/sec/{print \$2}")
  TR=$(echo "$W" | awk "/Transfer\/sec/{print \$2}")
  P99=$(echo "$W" | awk "/99%/{print \$2}")
  GBPS=$(python3 - "$TR" <<PYEOF
import sys
t = sys.argv[1]
mult = {"KB":1e3, "MB":1e6, "GB":1e9}
for suf, m in mult.items():
    if t.endswith(suf):
        print(round(float(t[:-2]) * m * 8 / 1e9, 3)); break
else:
    print(0)
PYEOF
)
  ERR=$(echo "$W" | grep -cE "Non-2xx|Socket errors")
  echo "RES capy closed NB=$NB c=$C rps=$RPS gbps=$GBPS p99=$P99 errlines=$ERR" | tee -a $OUT
  sleep 2
done
