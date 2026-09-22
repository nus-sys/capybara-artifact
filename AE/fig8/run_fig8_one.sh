#!/bin/bash
# Fig-8 single run (step-function workload, 2 backends on node9).
# usage: run_fig8_one.sh <LWRR|REACT|CAPY> <runid>
# Assumes: switch up with main_eval + fig8 setup (fig8_bringup.sh), iokerneld up on node7.
COND=$1; RID=$2
ID=fig8${COND}-${RID}
D=${CAPYBARA_DATA:-$HOME/capybara-data}       # parse .sh scripts hardcode this path
T=/homes/inho/Capybara/capybara-fig8        # dedicated fig8 tree (fig7 tree untouched)
# 200ms warmup prefix (client discards first 200ms of trace), then the paper's 120ms step spec
LS='90000:200000,90000:30000,270000:20000,450000:20000,630000:20000,810000:30000/90000:320000'

case $COND in
  LWRR)  MIGENV="MAX_REACTIVE_MIGS=0 MAX_PROACTIVE_MIGS=0 SIGNAL_POLICY_MIGS=0 RECV_QUEUE_LEN_THRESHOLD=1000000" ;;
  REACT) MIGENV="MAX_REACTIVE_MIGS=0 MAX_PROACTIVE_MIGS=0 SIGNAL_POLICY_MIGS=1 MIG_QUEUE_TRIGGER_LEN=${QTL:-10} FAIR_SHARE_N=2 MIG_CONN_RPS_CAP=${CAP:-200} MIG_COOLDOWN_MS=${MCD:-5} RECV_QUEUE_LEN_THRESHOLD=1000000" ;;
  CAPY)  MIGENV="MAX_REACTIVE_MIGS=100000 MAX_PROACTIVE_MIGS=0 SIGNAL_POLICY_MIGS=1 FAIR_SHARE_N=2 MIG_THRESHOLD_PCT=${PCT:-60} MIG_INDIVIDUAL_FLOOR=${FLOOR:-250} MIG_CONN_RPS_CAP=${CAP:-200} RECV_QUEUE_LEN_THRESHOLD=20 MIG_COOLDOWN_MS=${MCD:-10} REACTIVE_COOLDOWN_MS=${RCD:-10}" ;;
  *) echo "bad cond"; exit 1 ;;
esac

# 1) fresh servers + dpdk-ctrl on node9
ssh node9 "sudo pkill -INT -x http-server.elf 2>/dev/null; sleep 1; sudo pkill -x http-server.elf 2>/dev/null; for p in 0 1; do tmux kill-session -t f8s\$p 2>/dev/null; done; sudo pkill -x dpdk-ctrl.elf 2>/dev/null; tmux kill-session -t dc9 2>/dev/null; true" >/dev/null 2>&1
sleep 2
ssh node9 "tmux new-session -d -s dc9 \"cd $T && make PREFIX=/homes/inho dpdk-ctrl-node9 > /tmp/ae-dc9.log 2>&1\"" >/dev/null 2>&1
sleep 14
ssh node9 "cd $T; for p in 0 1; do c=\$((p+1)); tmux new-session -d -s f8s\$p \"cd $T && sudo -E env LOG_EVERY_RPS_SIGNAL=1 $MIGENV MIG_DELAY=0 MIG_PER_N=10 CONFIGURED_STATE_SIZE=0 MIN_THRESHOLD=1000000 RPS_THRESHOLD=0.3 THRESHOLD_EPSILON=0.1 CORE_ID=\$c CONFIG_PATH=scripts/config/node9_config.yaml MTU=9000 MSS=9000 NUM_CORES=4 USE_JUMBO=1 LIBOS=catnip DATA_SIZE=256 LD_LIBRARY_PATH=\\/homes/inho/lib:\\/homes/inho/lib/x86_64-linux-gnu numactl -m0 bin/examples/rust/http-server.elf 10.0.1.9:1000\$p > $D/$ID.be\$p 2>&1\"; sleep 2; done" >/dev/null 2>&1
sleep 3
NSRV=$(ssh node9 "pgrep -c http-server.el" 2>/dev/null)
if [ "$NSRV" != "2" ]; then echo "SERVERS=$NSRV (want 2) — abort"; exit 1; fi

# 2) client (step workload, 100 conns, zipf-1.2 within server groups)
tmux kill-session -t f8c 2>/dev/null
rm -f $D/$ID.client $D/$ID.request_sched $D/$ID.latency_trace $D/$ID.server_reply $D/$ID.latency $D/$ID.latency_count
tmux new-session -d -s f8c "cd /homes/inho/Capybara/caladan-fig8 && sudo numactl -m0 apps/synthetic/target/release/synthetic 10.0.1.8:55555 --config client_node7.config --mode runtime-client --protocol=http --transport=tcp --samples=1 --pps=10 --threads=100 --runtime=1 --discard_pct=0 --output=trace --rampup=0 --loadshift=$LS --zipf=1.2 --exptid=$D/$ID > $D/$ID.client 2>&1"
for i in $(seq 1 30); do grep -q "Median (us)\|panic" $D/$ID.client 2>/dev/null && break; pgrep -x synthetic >/dev/null || break; sleep 1; done
sleep 2

# 3) graceful server stop -> time-log dump to .be files
ssh node9 "sudo pkill -INT -x http-server.elf" >/dev/null 2>&1
sleep 3
ssh node9 "sudo pkill -x http-server.elf 2>/dev/null; true" >/dev/null 2>&1

# 4) parse
cd $T/eval
sh parse_request_sched.sh $ID >/dev/null 2>&1
sh parse_server_reply.sh $ID >/dev/null 2>&1
python3 ~/capybara-AE-runs/fig8/parse_rps_fig8.py $ID

# 5) summary
SIG0=$(grep -c ",RPS_SIGNAL," $D/$ID.be0 2>/dev/null)
SIG1=$(grep -c ",RPS_SIGNAL," $D/$ID.be1 2>/dev/null)
MIG=$(grep -c "INIT_MIG" $D/$ID.be0 $D/$ID.be1 2>/dev/null | awk -F: "{s+=\$2} END {print s}")
REQ=$(wc -l < $D/$ID.sched_ms_req 2>/dev/null)
LAT=$(wc -l < $D/$ID.server_ms_avg_99p_lat 2>/dev/null)
echo "DONE $ID: signals be0=$SIG0 be1=$SIG1 migs=$MIG sched_ms=$REQ lat_ms=$LAT client=$(grep -c 'Median (us)' $D/$ID.client 2>/dev/null)"
