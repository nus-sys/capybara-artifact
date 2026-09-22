#!/bin/bash
# Migration latency, TLS panel — one connection state size.
#
# One https backend on node8 and one on node9, both on port 10000, each in
# `migrate` mode: the server migrates a connection the moment its TLS session is
# established, the buffered request replays at the target, and the connection
# ping-pongs between the two hosts on its own. The stack addresses each prepare
# to its partner directly (as the paper-era stack did), so the switch runs the
# plain port_forward baseline and only forwards.
#
# usage: run_miglat_tls.sh <state_size_bytes> <runid>
# Assumes the port_forward baseline is up (cleanup_all.sh leaves it running).
set -u
SZ=$1; RID=${2:-run1}
ID=miglattls${SZ}-${RID}
D=${CAPYBARA_DATA:-$HOME/capybara-data}
T=/homes/inho/Capybara/capybara-fig14
CONNS=${CONNS:-16}
NREQ=${NREQ:-3000000}

POLICY="NUM_BE=2 MAX_PROACTIVE_MIGS=${MPM:-24} MAX_REACTIVE_MIGS=0 SIGNAL_POLICY_MIGS=0 \
RECV_QUEUE_LEN_THRESHOLD=${RQT:-20} MIN_THRESHOLD=${MINT:-190} \
RPS_THRESHOLD=0.3 THRESHOLD_EPSILON=0.1 MIG_DELAY=0"

# 1) fresh dpdk-ctrl + one https backend per node, both in migrate mode
for N in 8 9; do
  ssh node$N "sudo pkill -INT -x https.elf 2>/dev/null; sleep 1; sudo pkill -x https.elf 2>/dev/null; tmux kill-session -t tlss 2>/dev/null; sudo pkill -x dpdk-ctrl.elf 2>/dev/null; tmux kill-session -t dc$N 2>/dev/null; true" >/dev/null 2>&1 &
done; wait
sleep 2
for N in 8 9; do
  ssh node$N "tmux new-session -d -s dc$N \"cd $T && make PREFIX=/homes/inho dpdk-ctrl-node$N > /tmp/ae-dc$N.log 2>&1\"" >/dev/null 2>&1 &
done; wait
sleep 15
for N in 8 9; do
  ssh node$N "tmux new-session -d -s tlss \"cd $T && sudo -E env $POLICY CONFIGURED_STATE_SIZE=$SZ CAPY_LOG=all CORE_ID=1 CONFIG_PATH=scripts/config/node${N}_config.yaml MTU=9000 MSS=9000 NUM_CORES=4 USE_JUMBO=1 LIBOS=catnip DATA_SIZE=256 LD_LIBRARY_PATH=\\/homes/inho/lib:\\/homes/inho/lib/x86_64-linux-gnu numactl -m0 bin/examples/rust/https.elf 10.0.1.$N:10000 migrate > $D/$ID.be$((N-8)) 2>&1\"" >/dev/null 2>&1 &
done; wait
sleep 4
NSRV=$(for N in 8 9; do ssh node$N "pgrep -c https.el" 2>/dev/null; done | paste -sd+ | bc)
if [ "$NSRV" != "2" ]; then echo "RES tls $SZ SERVERS=$NSRV want=2 ABORT"; exit 1; fi

# 2) redis-benchmark over TLS, straight at the first backend as the paper did
TLSARGS="--tls --cert /usr/local/tls/svr.crt --key /usr/local/tls/svr.key --cacert /usr/local/tls/CA.pem"
tmux kill-session -t tlsc 2>/dev/null; sudo pkill -x redis-benchmark 2>/dev/null
rm -f $D/$ID.client
tmux new-session -d -s tlsc "sudo timeout ${TMO:-60} numactl -m0 /homes/inho/Capybara/capybara-redis/src/redis-benchmark $TLSARGS -h 10.0.1.8 -p 10000 -t get -n $NREQ -c $CONNS --threads $CONNS > $D/$ID.client 2>&1"
sleep ${RT:-20}
tmux kill-session -t tlsc 2>/dev/null; sudo pkill -x redis-benchmark 2>/dev/null
sleep 1

# 3) graceful stop so the time logs are flushed
for N in 8 9; do ssh node$N "sudo pkill -INT -x https.elf" >/dev/null 2>&1 & done; wait
sleep 5
for N in 8 9; do ssh node$N "sudo pkill -x https.elf 2>/dev/null; true" >/dev/null 2>&1 & done; wait

# 4) what came out
INIT=$(grep -c ",INIT_MIG," $D/$ID.be0 $D/$ID.be1 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
ACC=$(grep -c ",CONN_ACCEPTED," $D/$ID.be0 $D/$ID.be1 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
echo "RES tls $SZ id=$ID init_mig=$INIT conn_accepted=$ACC"
