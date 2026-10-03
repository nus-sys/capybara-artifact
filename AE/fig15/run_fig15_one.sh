#!/bin/bash
# Fig-15 single cell: one TCP connection, one response size, one migration
# frequency. Two http-server backends on node9 (ports 10000/10001) built from
# the Fig 8 tree with the manual (time-gated) migration feature: a backend
# re-initiates the connection's migration whenever MIG_PER_N microseconds have
# passed since the last one, and the switch (main_eval_fig8 program) sends it
# to the other backend. The client is one open-loop caladan connection on
# node7; the cell's result is the peak achieved request rate over a short
# offered-load ladder (the paper's method: offered load swept, "Actual" taken).
#
# usage: run_fig15_one.sh <DATA_SIZE bytes> <migrations per second> ["<pps ladder>"]
# Assumes: fig8_bringup.sh done (switch main_eval_fig8 + pktgen, iokerneld on node7).
set -u
SZ=$1; FREQ=$2; LADDER=${3:-}
RT=${RT:-8}
T=/homes/inho/Capybara/capybara-fig15               # Fig 8 tree + manual-tcp-migration build
CL=/homes/inho/Capybara/caladan-fig8
D=${CAPYBARA_DATA:-$HOME/capybara-data}
OUT=${OUT:-$HOME/capybara-AE-runs/fig15/results_fig15.txt}
ID=fig15-s${SZ}-f${FREQ}
if [ "$FREQ" = 0 ]; then MIGN=0; else MIGN=$((1000000 / FREQ)); fi   # us between migrations

if [ -z "$LADDER" ]; then
  case $SZ in
    1024)  LADDER="300000 400000 500000 600000 700000 800000" ;;
    8192)  LADDER="200000 300000 400000 500000 600000 700000" ;;
    16384) LADDER="150000 200000 300000 400000 500000" ;;
    32768) LADDER="80000 120000 160000 200000 250000 300000" ;;
    65536) LADDER="50000 80000 110000 140000 170000 200000" ;;
    *)     LADDER="50000 100000 200000 400000" ;;
  esac
fi

MIGENV="MAX_REACTIVE_MIGS=0 MAX_PROACTIVE_MIGS=0 SIGNAL_POLICY_MIGS=0 RECV_QUEUE_LEN_THRESHOLD=1000000"

# 1) fresh dpdk-ctrl + two backends on node9
ssh node9 "sudo pkill -INT -x http-server.elf 2>/dev/null; sleep 1; sudo pkill -x http-server.elf 2>/dev/null; for p in 0 1; do tmux kill-session -t f15s\$p 2>/dev/null; done; sudo pkill -x dpdk-ctrl.elf 2>/dev/null; tmux kill-session -t dc9 2>/dev/null; true" >/dev/null 2>&1
sleep 2
ssh node9 "tmux new-session -d -s dc9 \"cd $T && make PREFIX=/homes/inho dpdk-ctrl-node9 > /tmp/ae-dc9.log 2>&1\"" >/dev/null 2>&1
sleep 14
rm -f $D/$ID.be0 $D/$ID.be1
ssh node9 "cd $T; for p in 0 1; do c=\$((p+1)); tmux new-session -d -s f15s\$p \"cd $T && sudo -E env $MIGENV MIG_DELAY=0 MIG_PER_N=$MIGN CONFIGURED_STATE_SIZE=0 MIN_THRESHOLD=1000000 RPS_THRESHOLD=0.3 THRESHOLD_EPSILON=0.1 CORE_ID=\$c CONFIG_PATH=scripts/config/node9_config.yaml MTU=9000 MSS=9000 NUM_CORES=4 USE_JUMBO=1 LIBOS=catnip DATA_SIZE=$SZ LD_LIBRARY_PATH=\\/homes/inho/lib:\\/homes/inho/lib/x86_64-linux-gnu numactl -m0 bin/examples/rust/http-server.elf 10.0.1.9:1000\$p > $D/$ID.be\$p 2>&1\"; sleep 2; done" >/dev/null 2>&1
sleep 3
NSRV=$(ssh node9 "pgrep -c http-server.el" 2>/dev/null)
if [ "$NSRV" != "2" ]; then echo "RES fig15 size=$SZ freq=$FREQ SERVERS=$NSRV want=2 ABORT" | tee -a $OUT; exit 1; fi

# 2) offered-load ladder, one connection, open-loop; keep the best achieved rate
PEAK=0; PEAK_AT=0; STEPS=0; DETAIL=""
for PPS in $LADDER; do
  tmux kill-session -t f15c 2>/dev/null; sudo pkill -x synthetic 2>/dev/null
  rm -f /tmp/ae-f15.log
  tmux new-session -d -s f15c "cd $CL && sudo timeout $((RT + 40)) numactl -m0 apps/synthetic/target/release/synthetic 10.0.1.8:55555 --config client_node7.config --mode runtime-client --protocol=http --transport=tcp --samples=1 --pps=$PPS --threads=1 --runtime=$RT --discard_pct=0 --output=buckets --rampup=0 --exptid=/tmp/ae-f15x > /tmp/ae-f15.log 2>&1; echo CLIENT_EXIT=\$? >> /tmp/ae-f15.log"
  # wait for the client to finish (it exits by itself after --runtime seconds)
  for i in $(seq 1 $((RT + 45))); do grep -aq "CLIENT_EXIT" /tmp/ae-f15.log 2>/dev/null && break; sleep 1; done
  R=$(grep -a "\[RESULT\]" /tmp/ae-f15.log 2>/dev/null | tail -1 | sed 's/.*\[RESULT\] *//')
  ACH=$(echo "$R" | awk -F', *' '{print $2+0}')
  STEPS=$((STEPS + 1)); DETAIL="$DETAIL $PPS:${ACH:-0}"
  if [ "${ACH:-0}" -gt "$PEAK" ]; then PEAK=$ACH; PEAK_AT=$PPS; fi
  # keep climbing through the whole ladder (a single low step can be a transient); the
  # cell's value is the best achieved rate
done
tmux kill-session -t f15c 2>/dev/null; sudo pkill -x synthetic 2>/dev/null

# 3) graceful stop -> time logs flushed; count the migrations the cell performed
ssh node9 "sudo pkill -INT -x http-server.elf" >/dev/null 2>&1
# the time-log dump of a high-frequency cell is large: wait for the servers to exit
for i in $(seq 1 40); do ssh node9 "pgrep -x http-server.elf >/dev/null" 2>/dev/null || break; sleep 1; done
ssh node9 "sudo pkill -x http-server.elf 2>/dev/null; true" >/dev/null 2>&1
sleep 1
MIGS=$(grep -c ",INIT_MIG," $D/$ID.be0 $D/$ID.be1 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')

# 4) throughput: HTTP response bytes (status line + Content-Length header + body)
HDR=$((37 + ${#SZ}))
GBPS=$(python3 -c "print(f'{$PEAK * ($SZ + $HDR) * 8 / 1e9:.3f}')")
echo "RES fig15 size=$SZ freq=$FREQ mign_us=$MIGN peak_rps=$PEAK at_pps=$PEAK_AT gbps=$GBPS migs=$MIGS secs=$((STEPS * RT)) steps=$STEPS detail=$DETAIL" | tee -a $OUT
