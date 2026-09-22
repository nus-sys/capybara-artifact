#!/bin/bash
# Migration latency, TLS panel — one state size, on the paper-era stack.
#
# The tree is the monorepo at 4599b186, the commit the day before the paper's
# runs: the stack addresses each prepare to the partner port itself
# (10000 <-> 10001) at FRONTEND_IP, so both https backends live on node8 — the
# FRONTEND_IP host — sharing one clock, and the prepare hairpins through the
# port_forward baseline by MAC. Servers run in `migrate` mode as the paper's
# driver started them (EVAL_MIG_DELAY appends the argv).
#
# usage: run_miglat_tls2.sh <state_size_bytes> <runid>
set -u
SZ=$1; RID=${2:-run1}
ID=miglattcp2-${SZ}-${RID}
D=${CAPYBARA_DATA:-$HOME/capybara-data}
T=/homes/inho/Capybara/capybara-fig14tls
CONNS=${CONNS:-16}
NREQ=${NREQ:-3000000}

POLICY="NUM_BE=2 MAX_PROACTIVE_MIGS=${MPM:-24} MAX_REACTIVE_MIGS=0 \
RECV_QUEUE_LEN_THRESHOLD=${RQT:-20} MIN_THRESHOLD=${MINT:-190} \
RPS_THRESHOLD=0.3 THRESHOLD_EPSILON=0.1 MIG_DELAY=0"

# 1) fresh dpdk-ctrl + two https backends on node8, both in migrate mode
ssh node8 "sudo pkill -INT -x http-server.elf 2>/dev/null; sleep 1; sudo pkill -x http-server.elf 2>/dev/null; for p in 0 1; do tmux kill-session -t tls\$p 2>/dev/null; done; sudo pkill -x dpdk-ctrl.elf 2>/dev/null; tmux kill-session -t dc8 2>/dev/null; true" >/dev/null 2>&1
sleep 2
ssh node8 "tmux new-session -d -s dc8 \"cd $T && make PREFIX=/homes/inho dpdk-ctrl-node8 > /tmp/ae-dc8.log 2>&1\"" >/dev/null 2>&1
sleep 14
ssh node8 "cd $T; for p in 0 1; do c=\$((p+1)); tmux new-session -d -s tls\$p \"cd $T && sudo -E env $POLICY CONFIGURED_STATE_SIZE=$SZ CAPY_LOG=all CORE_ID=\$c CONFIG_PATH=scripts/config/node8_config.yaml MTU=9000 MSS=9000 NUM_CORES=4 USE_JUMBO=1 LIBOS=catnip DATA_SIZE=256 LD_LIBRARY_PATH=\\/homes/inho/lib:\\/homes/inho/lib/x86_64-linux-gnu numactl -m0 bin/examples/rust/http-server.elf 10.0.1.8:1000\$p migrate > $D/$ID.be\$p 2>&1\"; sleep 2; done" >/dev/null 2>&1
sleep 4
NSRV=$(ssh node8 "pgrep -c http-server.el" 2>/dev/null)
if [ "$NSRV" != "2" ]; then echo "RES tls $SZ SERVERS=$NSRV want=2 ABORT"; exit 1; fi

# 2) redis-benchmark over TLS, straight at the first backend as the paper did
TLSARGS="--tls --cert /usr/local/tls/svr.crt --key /usr/local/tls/svr.key --cacert /usr/local/tls/CA.pem"
tmux kill-session -t tlsc 2>/dev/null; sudo pkill -x redis-benchmark 2>/dev/null
rm -f $D/$ID.client
tmux new-session -d -s tlsc "sudo timeout ${TMO:-60} numactl -m0 /homes/inho/Capybara/capybara-redis/src/redis-benchmark -h 10.0.1.8 -p 10000 -t get -n $NREQ -c $CONNS --threads $CONNS > $D/$ID.client 2>&1"
sleep ${RT:-15}
tmux kill-session -t tlsc 2>/dev/null; sudo pkill -x redis-benchmark 2>/dev/null
sleep 1

# 3) graceful stop so the time logs are flushed
ssh node8 "sudo pkill -INT -x http-server.elf" >/dev/null 2>&1
sleep 5
ssh node8 "sudo pkill -x http-server.elf 2>/dev/null; true" >/dev/null 2>&1

# 4) what came out
INIT=$(grep -c ",INIT_MIG," $D/$ID.be0 $D/$ID.be1 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
ACC=$(grep -c ",CONN_ACCEPTED," $D/$ID.be0 $D/$ID.be1 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
echo "RES tls $SZ id=$ID init_mig=$INIT conn_accepted=$ACC"
