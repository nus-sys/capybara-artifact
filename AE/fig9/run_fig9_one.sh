#!/bin/bash
# Fig-9 single run (redis latency CDF, 2 redis-on-shim backends on node9).
# usage: run_fig9_one.sh <LWRR|CAPY> <runid>
# Assumes: switch up with main_eval_fig8 program + fig8 setup (fig8_bringup.sh), iokerneld on node7.
COND=$1; RID=$2
ID=fig9${COND}-${RID}
D=${CAPYBARA_DATA:-$HOME/capybara-data}
T=/homes/inho/Capybara/capybara-fig9
LS=$(cat ~/capybara-AE-runs/fig9/gen/loadshift_spec.txt)

COMMON="LOG_EVERY_RPS_SIGNAL=1 MIG_DELAY=0 MIG_PER_N=100 CONFIGURED_STATE_SIZE=0 MIN_THRESHOLD=1000000 RPS_THRESHOLD=0.3 THRESHOLD_EPSILON=0.1 MTU=9000 MSS=9000 NUM_CORES=4 USE_JUMBO=1 LIBOS=catnip"
case $COND in
  LWRR) MIGENV="$COMMON SIGNAL_POLICY_MIGS=0 MAX_REACTIVE_MIGS=0 MAX_PROACTIVE_MIGS=0 RECV_QUEUE_LEN_THRESHOLD=1000000" ;;
  CAPY) MIGENV="$COMMON SIGNAL_POLICY_MIGS=1 MAX_REACTIVE_MIGS=0 MAX_PROACTIVE_MIGS=0 FAIR_SHARE_N=2 MIG_THRESHOLD_PCT=${PCT:-65} MIG_INDIVIDUAL_FLOOR=${FLOOR:-150} MIG_CONN_RPS_CAP=${CAP:-30} MIG_COOLDOWN_MS=${MCD:-10} MIG_ONLY_IDLE=${IDLE:-0} RECV_QUEUE_LEN_THRESHOLD=1000000" ;;
  *) echo "bad cond"; exit 1 ;;
esac

# 1) fresh redis servers + dpdk-ctrl on node9
ssh node9 "sudo pkill -x redis-server 2>/dev/null; sleep 1; for p in 0 1; do tmux kill-session -t f9s\$p 2>/dev/null; done; sudo pkill -x dpdk-ctrl.elf 2>/dev/null; tmux kill-session -t dc9 2>/dev/null; true" >/dev/null 2>&1
sleep 2
ssh node9 "tmux new-session -d -s dc9 \"cd $T && make PREFIX=/homes/inho dpdk-ctrl-node9 > /tmp/ae-dc9.log 2>&1\"" >/dev/null 2>&1
sleep 14
for p in 0 1; do
  ssh node9 "tmux new-session -d -s f9s$p \"cd $T && sudo -E env $MIGENV PREFIX=/homes/inho make redis-server-node9-1000$p REDIS_SERVER_PATH=capybara-redis REDIS_CONFIG=../config/node9_1000${p}_tcp.conf ENV= LD_LIBRARY_PATH=/homes/inho/Capybara/capybara-fig9/lib:/homes/inho/lib:/homes/inho/lib/x86_64-linux-gnu > $D/$ID.be$p 2>&1\"" >/dev/null 2>&1
  sleep 2
done
sleep 4
NSRV=$(ssh node9 "pgrep -c redis-server" 2>/dev/null)
if [ "$NSRV" != "2" ]; then echo "REDIS=$NSRV (want 2) — abort"; exit 1; fi

# 2) client (resp protocol, 100 conns, generated 5s loadshift, zipf-1.2)
tmux kill-session -t f9c 2>/dev/null
rm -f $D/$ID.client $D/$ID.request_sched $D/$ID.latency_trace $D/$ID.latency $D/$ID.latency_count $D/$ID.lat_cdf
tmux new-session -d -s f9c "cd /homes/inho/Capybara/caladan-fig8 && sudo env REDIS_PRELOAD=0 numactl -m0 apps/synthetic/target-noreply/release/synthetic 10.0.1.8:55555 --config client_node7.config --mode runtime-client --protocol=resp --redis-string=1000000 --transport=tcp --samples=1 --pps=10 --threads=100 --runtime=5 --discard_pct=10 --output=trace --rampup=0 --loadshift=$LS --zipf=1.2 --exptid=$D/$ID > $D/$ID.client 2>&1"
for i in $(seq 1 180); do pgrep -x synthetic >/dev/null || break; sleep 1; done
# wait until the latency trace stops growing (client writes it at exit)
PREV=-1
for i in $(seq 1 10); do
  SZ=$(stat -c %s $D/$ID.latency_trace 2>/dev/null || echo 0)
  [ "$SZ" != "0" ] && [ "$SZ" = "$PREV" ] && break
  PREV=$SZ; sleep 2
done

# 3) stop servers
ssh node9 "sudo pkill -INT -x redis-server 2>/dev/null; sleep 1; sudo pkill -x redis-server 2>/dev/null; true" >/dev/null 2>&1

# 4) parse (client latency trace -> top-tail CDF)
cd $T/eval && sh latency_cdf.sh $ID >/dev/null 2>&1

# 5) summary
NCDF=$(wc -l < $D/$ID.lat_cdf 2>/dev/null)
P99=$(awk -F, "\$2>=0.99 {print \$1; exit}" $D/$ID.lat_cdf 2>/dev/null)
MED=$(grep -oE "Median \(us\): [0-9]+" $D/$ID.client | grep -oE "[0-9]+$" | tail -1)
echo "DONE $ID: cdf_lines=$NCDF p99=${P99}us median=${MED}us client=$(grep -c 'Median (us)' $D/$ID.client 2>/dev/null)"
