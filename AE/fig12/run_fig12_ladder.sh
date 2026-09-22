#!/bin/bash
# Fig12 connection-scalability ladder: per rung, fresh servers, then 12 wrk2
# processes (node5/6/7 x 4, 10 cores each, distinct source-port ranges,
# -R200000 each => 2.4M rps offered) against the 10.0.1.8:55555 VIP for 20 s.
# Total throughput = sum of the 12 processes' Requests/sec.
# usage: run_fig12_ladder.sh <label> "<per-process conn list>" [duration]
#   figure ladder: 12 120 240 600 1200 2400 3600 4800 6000 9600 13200 16128
#   (x-axis = conns x 12)
set -u
LABEL=$1; CONNS=${2:-"12 1200 16128"}; DUR=${3:-20}
T=/homes/inho/Capybara/capybara-fig12
OUT=~/capybara-AE-runs/fig12/results_fig12.txt
D=~/capybara-AE-runs/fig12/raw
mkdir -p $D

start_servers () {
  for N in 8 9 10; do ssh node$N "sudo pkill -f http-server 2>/dev/null; sudo pkill -x dpdk-ctrl.elf 2>/dev/null; tmux kill-server 2>/dev/null; sudo rm -rf /var/run/dpdk/rte 2>/dev/null; true" >/dev/null 2>&1; done
  sleep 2
  for N in 8 9 10; do ssh node$N "tmux new-session -d -s dc$N \"cd $T && make PREFIX=/homes/inho dpdk-ctrl-node$N > /tmp/ae-dc$N.log 2>&1\"" >/dev/null 2>&1; done
  sleep 22
  for j in $(seq 0 11); do
    N=$((8 + j % 3)); CORE=$((j / 3 + 1)); PORT=$((10000 + j / 3))
    ssh node$N "tmux new-session -d -s sv$CORE \"cd $T && sudo -E env CORE_ID=$CORE CONFIG_PATH=$T/scripts/config/node${N}_config.yaml MTU=9000 MSS=9000 NUM_CORES=4 USE_JUMBO=1 LIBOS=catnip DATA_SIZE=256 LD_LIBRARY_PATH=\\/homes/inho/lib:\\/homes/inho/lib/x86_64-linux-gnu numactl -m0 timeout 3600 $T/bin/examples/rust/http-server.elf 10.0.1.$N:$PORT > /tmp/ae-sv${N}_$CORE.log 2>&1\"" >/dev/null 2>&1
  done
  sleep 6
}

for C in $CONNS; do
  start_servers
  CODE=$(timeout 8 curl -s -o /dev/null -w "%{http_code}" http://10.0.1.8:55555/get)
  if [ "$CODE" != "200" ]; then
    echo "RES fig12 $LABEL conn=$((C*12)) SANITY-FAIL" | tee -a $OUT
    continue
  fi
  ID="$LABEL-c$C"
  rm -f $D/$ID.*
  TVAL=10; [ "$C" -lt 10 ] && TVAL=$C
  for CL in 5 6 7; do
    for i in 0 1 2 3; do
      SP=$((1024 + 16128 * i))
      SC=$((i * 10)); EC=$((SC + 9))
      CMD="taskset -c $SC-$EC sudo numactl -m0 /homes/inho/wrk-tools/wrk2/wrk -t$TVAL -c$C -P$SP-$((SP + C - 1)) -d${DUR}s -R200000 --latency http://10.0.1.8:55555/get > $D/$ID.node$CL.p$i 2>&1"
      if [ "$CL" = "7" ]; then
        tmux new-session -d -s w$i "$CMD"
      else
        ssh node$CL "tmux new-session -d -s w$i \"$CMD\"" >/dev/null 2>&1 &
      fi
    done
  done
  wait
  sleep $((DUR + 25))
  for CL in 5 6; do ssh node$CL "sudo pkill -x wrk 2>/dev/null; true" >/dev/null 2>&1; done
  sudo pkill -x wrk 2>/dev/null
  TOT=$(grep -h "Requests/sec" $D/$ID.* 2>/dev/null | awk "{s+=\$2} END {printf \"%.0f\", s}")
  NPROC=$(grep -lh "Requests/sec" $D/$ID.* 2>/dev/null | wc -l)
  echo "RES fig12 $LABEL conn=$((C*12)) total_rps=${TOT:-0} procs=$NPROC" | tee -a $OUT
done
