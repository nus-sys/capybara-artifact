#!/bin/bash
# Migration latency, TCP panel — one connection state size.
#
# The paper's layout: both http backends on node9, ports 10000 and 10001, so
# every phase timestamp comes from one clock. Each accept initiates a migration
# (bounded at 11,000 per server), so a connection ping-pongs between the two
# ports on its own; the synthetic connection state comes from
# CONFIGURED_STATE_SIZE. The switch runs the port_forward baseline and the
# prepare hairpins through it by MAC.
#
# usage: run_miglat_tcp.sh <state_size_bytes> <runid>
set -u
SZ=$1; RID=${2:-run1}
ID=miglattcp${SZ}-${RID}
D=${CAPYBARA_DATA:-$HOME/capybara-data}
T=/homes/inho/Capybara/capybara-fig14
CONNS=${CONNS:-16}
NREQ=${NREQ:-3000000}

POLICY="NUM_BE=2 MAX_PROACTIVE_MIGS=${MPM:-24} MAX_REACTIVE_MIGS=0 SIGNAL_POLICY_MIGS=0 \
RECV_QUEUE_LEN_THRESHOLD=${RQT:-20} MIN_THRESHOLD=${MINT:-190} \
RPS_THRESHOLD=0.3 THRESHOLD_EPSILON=0.1 MIG_DELAY=0"

# 1) fresh dpdk-ctrl + two http backends on node9
ssh node9 "sudo pkill -INT -x http-server.elf 2>/dev/null; sleep 1; sudo pkill -x http-server.elf 2>/dev/null; for p in 0 1; do tmux kill-session -t mig\$p 2>/dev/null; done; sudo pkill -x dpdk-ctrl.elf 2>/dev/null; tmux kill-session -t dc9 2>/dev/null; true" >/dev/null 2>&1
sleep 2
ssh node9 "tmux new-session -d -s dc9 \"cd $T && make PREFIX=/homes/inho dpdk-ctrl-node9 > /tmp/ae-dc9.log 2>&1\"" >/dev/null 2>&1
sleep 14
ssh node9 "cd $T; for p in 0 1; do c=\$((p+1)); tmux new-session -d -s mig\$p \"cd $T && sudo -E env $POLICY CONFIGURED_STATE_SIZE=$SZ CAPY_LOG=all CORE_ID=\$c CONFIG_PATH=scripts/config/node9_config.yaml MTU=9000 MSS=9000 NUM_CORES=4 USE_JUMBO=1 LIBOS=catnip DATA_SIZE=256 LD_LIBRARY_PATH=\\/homes/inho/lib:\\/homes/inho/lib/x86_64-linux-gnu numactl -m0 bin/examples/rust/http-server.elf 10.0.1.9:1000\$p > $D/$ID.be\$p 2>&1\"; sleep 2; done" >/dev/null 2>&1
sleep 4
NSRV=$(ssh node9 "pgrep -c http-server.el" 2>/dev/null)
if [ "$NSRV" != "2" ]; then echo "RES tcp $SZ SERVERS=$NSRV want=2 ABORT"; exit 1; fi

# 2) plain redis-benchmark at the first backend
tmux kill-session -t migc 2>/dev/null; sudo pkill -x redis-benchmark 2>/dev/null
rm -f $D/$ID.client
tmux new-session -d -s migc "sudo timeout ${TMO:-60} numactl -m0 /homes/inho/Capybara/capybara-redis/src/redis-benchmark -h 10.0.1.9 -p 10000 -t get -n $NREQ -c $CONNS --threads $CONNS > $D/$ID.client 2>&1"
sleep ${RT:-15}
tmux kill-session -t migc 2>/dev/null; sudo pkill -x redis-benchmark 2>/dev/null
sleep 1

# 3) graceful stop so the time logs are flushed
ssh node9 "sudo pkill -INT -x http-server.elf" >/dev/null 2>&1
sleep 5
ssh node9 "sudo pkill -x http-server.elf 2>/dev/null; true" >/dev/null 2>&1

# 4) what came out
INIT=$(grep -c ",INIT_MIG," $D/$ID.be0 $D/$ID.be1 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
ACC=$(grep -c ",CONN_ACCEPTED," $D/$ID.be0 $D/$ID.be1 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
echo "RES tcp $SZ id=$ID init_mig=$INIT conn_accepted=$ACC"
