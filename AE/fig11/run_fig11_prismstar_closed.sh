#!/bin/bash
# Fig11 closed-loop panel, Prism (prism-star, the paper's plotted "Prism"):
# the DPDK/catnip reimplementation from /homes/inho/Capybara/prism-star, driven exactly as
# its own eval/run_eval.py did (prism switch program, prism-fe on node8,
# prism-be-http on node9:1000j, NUM_BE env). Backends launch before the
# frontend (the FE handshakes with them at startup). Servers restart per rung.
# usage: run_fig11_prismstar_closed.sh <NB> "<conn list>" [dur_s]
set -u
NB=$1; CONNS=${2:-"10 18 50"}; DUR=${3:-10}
P=/homes/inho/Capybara/prism-star
OUT=~/capybara-AE-runs/fig11/results_closed_prismstar.txt
DS=131072

# prism switch program + tables (same bring-up as the kernel-prism validation)
bash ~/capybara-AE-runs/fig11/fig11_bringup_prism.sh >/dev/null 2>&1

start_servers () {
  for N in 8 9; do ssh node$N "sudo pkill -INT -x prism-fe.elf 2>/dev/null; sudo pkill -INT -x prism-be-http.e 2>/dev/null; sleep 1; sudo pkill -9 -x prism-fe.elf 2>/dev/null; sudo pkill -9 -x prism-be-http.e 2>/dev/null; true" >/dev/null 2>&1; done
  sleep 2
  for N in 8 9; do
    ssh node$N "pgrep -x dpdk-ctrl.elf >/dev/null" || {
      ssh node$N "sudo pkill -x dpdk-ctrl.elf 2>/dev/null; sudo rm -rf /var/run/dpdk/rte 2>/dev/null; tmux kill-session -t dc$N 2>/dev/null; tmux new-session -d -s dc$N \"cd $P && make PREFIX=/homes/inho dpdk-ctrl-node$N > /tmp/ae-dc$N.log 2>&1\"" >/dev/null 2>&1
      DPDK_STARTED=1
    }
  done
  [ "${DPDK_STARTED:-0}" = "1" ] && sleep 22
  for j in $(seq 0 $((NB-1))); do
    ssh node9 "tmux kill-session -t be$j 2>/dev/null; tmux new-session -d -s be$j \"cd $P && sudo -E env LIBOS=catnip CORE_ID=$((j+1)) NUM_BE=$NB MTU=9000 MSS=9000 DATA_SIZE=$DS CONFIG_PATH=$P/config/node9_config.yaml LD_LIBRARY_PATH=\\/homes/inho/lib:\\/homes/inho/lib/x86_64-linux-gnu numactl -m0 timeout 900 $P/bin/examples/rust/prism-be-http.elf 10.0.1.9:1000$j 10.0.1.8:10000 > /tmp/ae-pstbe$j.log 2>&1\"" >/dev/null 2>&1
  done
  sleep 4
  ssh node8 "tmux kill-session -t fe 2>/dev/null; tmux new-session -d -s fe \"cd $P && sudo -E env LIBOS=catnip CORE_ID=1 NUM_BE=$NB MTU=9000 MSS=9000 DATA_SIZE=$DS CONFIG_PATH=$P/config/node8_config.yaml LD_LIBRARY_PATH=\\/homes/inho/lib:\\/homes/inho/lib/x86_64-linux-gnu numactl -m0 timeout 900 $P/bin/examples/rust/prism-fe.elf 10.0.1.8:10000 > /tmp/ae-pstfe.log 2>&1\"" >/dev/null 2>&1
  sleep 8
}

for C in $CONNS; do
  # Up to 3 full bring-up attempts: prism FE/BE can miss the first try during
  # the switch link-flap window. Retry the whole bring-up, not just the curl.
  CODE=000
  for attempt in 1 2 3; do
    start_servers
    sleep $((attempt * 2))
    sudo ip route replace 10.0.1.8/32 dev ens85f1np1 advmss 8960 2>/dev/null
    CODE=$(timeout 12 curl -s -o /dev/null -w "%{http_code}" http://10.0.1.8:10000/get)
    [ "$CODE" != "200" ] && { sleep 4
      sudo ip route replace 10.0.1.8/32 dev ens85f1np1 advmss 8960 2>/dev/null
      CODE=$(timeout 12 curl -s -o /dev/null -w "%{http_code}" http://10.0.1.8:10000/get); }
    [ "$CODE" = "200" ] && break
    # tear prism processes down before the next attempt
    for N in 8 9; do ssh node$N "sudo pkill -INT -x prism-fe.elf 2>/dev/null; sudo pkill -INT -x prism-be-http.e 2>/dev/null; sleep 1; sudo pkill -9 -x prism-fe.elf 2>/dev/null; sudo pkill -9 -x prism-be-http.e 2>/dev/null; true" >/dev/null 2>&1; done
    sleep 2
  done
  if [ "$CODE" != "200" ]; then
    echo "RES prismstar closed NB=$NB c=$C SANITY-FAIL" | tee -a $OUT
    continue
  fi
  W=$(/homes/inho/wrk-tools/wrk/wrk -t$C -c$C -d${DUR}s --latency http://10.0.1.8:10000/get 2>&1)
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
  echo "RES prismstar closed NB=$NB c=$C rps=$RPS gbps=$GBPS p99=$P99 errlines=$ERR" | tee -a $OUT
  sleep 2
done
