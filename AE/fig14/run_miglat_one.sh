#!/bin/bash
# Migration-latency microbenchmark, one state size (paper Fig. state_size_vs_mig_latency).
#
# A connection is migrated back and forth between two backends while the servers
# timestamp each phase of the protocol. MIG_AFTER forces the migrations rather than
# waiting for load to trigger them, so a short run yields thousands of samples.
# CONFIGURED_STATE_SIZE adds application state on top of the 75-byte TCP state.
#
# usage: run_miglat_one.sh <state_size_bytes> <runid>
# Assumes the fig8 switch program and node7's iokerneld are already up
# (fig8/fig8_bringup.sh).
set -u
SZ=$1; RID=${2:-run1}
ID=miglat${SZ}-${RID}
D=${CAPYBARA_DATA:-$HOME/capybara-data}
T=/homes/inho/Capybara/capybara-fig14          # dedicated tree; fig8 and fig10 untouched
RUNTIME=${RT:-5}
MIG_AFTER=${MA:-100}

# Migration is driven by MIG_AFTER, so the load-based policies stay off; the RPS
# signal is left on because that is what teaches each backend who its partner is.
POLICY="SIGNAL_POLICY_MIGS=0 MAX_REACTIVE_MIGS=0 MAX_PROACTIVE_MIGS=0 RECV_QUEUE_LEN_THRESHOLD=1000000"

# 1) fresh dpdk-ctrl + two backends on node9
ssh node9 "sudo pkill -INT -x http-server.elf 2>/dev/null; sleep 1; sudo pkill -x http-server.elf 2>/dev/null; for p in 0 1; do tmux kill-session -t mls\$p 2>/dev/null; done; sudo pkill -x dpdk-ctrl.elf 2>/dev/null; tmux kill-session -t dc9 2>/dev/null; true" >/dev/null 2>&1
sleep 2
ssh node9 "tmux new-session -d -s dc9 \"cd $T && make PREFIX=/homes/inho dpdk-ctrl-node9 > /tmp/ae-dc9.log 2>&1\"" >/dev/null 2>&1
sleep 14
ssh node9 "cd $T; for p in 0 1; do c=\$((p+1)); tmux new-session -d -s mls\$p \"cd $T && sudo -E env LOG_EVERY_RPS_SIGNAL=1 $POLICY MIG_AFTER=$MIG_AFTER MIG_EVERY=${ME:-1} CONFIGURED_STATE_SIZE=$SZ MIG_DELAY=0 MIN_THRESHOLD=1000000 RPS_THRESHOLD=0.3 THRESHOLD_EPSILON=0.1 CORE_ID=\$c CONFIG_PATH=scripts/config/node9_config.yaml MTU=9000 MSS=9000 NUM_CORES=4 USE_JUMBO=1 LIBOS=catnip DATA_SIZE=256 LD_LIBRARY_PATH=\\/homes/inho/lib:\\/homes/inho/lib/x86_64-linux-gnu numactl -m0 bin/examples/rust/http-server.elf 10.0.1.9:1000\$p > $D/$ID.be\$p 2>&1\"; sleep 2; done" >/dev/null 2>&1
sleep 3
NSRV=$(ssh node9 "pgrep -c http-server.el" 2>/dev/null)
if [ "$NSRV" != "2" ]; then echo "RES $SZ SERVERS=$NSRV want=2 ABORT"; exit 1; fi

# 2) steady load; a small connection count keeps the migrating connection busy
tmux kill-session -t mlc 2>/dev/null; sudo pkill -x synthetic 2>/dev/null
rm -f $D/$ID.client
tmux new-session -d -s mlc "cd /homes/inho/Capybara/caladan-fig8 && sudo timeout 120 numactl -m0 apps/synthetic/target/release/synthetic 10.0.1.8:55555 --config client_node7.config --mode runtime-client --protocol=http --transport=tcp --samples=1 --pps=${PPS:-50000} --threads=${THREADS:-10} --runtime=$RUNTIME --discard_pct=0 --output=buckets --rampup=0 --exptid=$D/$ID > $D/$ID.client 2>&1"
for i in $(seq 1 90); do pgrep -x synthetic >/dev/null || break; sleep 1; done
sleep 2

# 3) graceful stop so the servers flush their time logs into the .be files
ssh node9 "sudo pkill -INT -x http-server.elf" >/dev/null 2>&1
sleep 4
ssh node9 "sudo pkill -x http-server.elf 2>/dev/null; true" >/dev/null 2>&1

# 4) what came out
DUMP0=$(grep -c "dumping time log data" $D/$ID.be0 2>/dev/null)
DUMP1=$(grep -c "dumping time log data" $D/$ID.be1 2>/dev/null)
INIT=$(grep -c ",INIT_MIG," $D/$ID.be0 $D/$ID.be1 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
ACK=$(grep -c ",RECV_STATE_ACK," $D/$ID.be0 $D/$ID.be1 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
echo "RES $SZ id=$ID dumps=$DUMP0/$DUMP1 init_mig=$INIT recv_state_ack=$ACK"
