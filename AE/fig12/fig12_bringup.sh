#!/bin/bash
# Fig12 bring-up: the src-rewriting-by-server switch program (SYN round-robin
# to 12 backends; servers themselves stamp replies with the 10.0.1.8:55555
# VIP), jumbo ports, then the era setup script run_eval used. Servers are the
# era http-server (listen backlog 1M) on node8/9/10, 4 per node, DATA_SIZE 256.
# usage: fig12_bringup.sh   (switch + servers; smoke separately)
T=/homes/inho/Capybara/capybara-fig12
ssh sw1 'for s in sw bft swset swov swov2 pktgen baseline blcfg rdr p4b; do tmux kill-session -t $s 2>/dev/null; done; sudo pkill -x bf_switchd 2>/dev/null; true' >/dev/null 2>&1
sleep 2
ssh sw1 'rm -f /tmp/ae-switchd.log; tmux new-session -d -s sw "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_switchd.sh -p capybara_switch_fe_src_rewriting_by_server > /tmp/ae-switchd.log 2>&1"' >/dev/null 2>&1
for i in $(seq 1 30); do ssh sw1 'grep -q "bfruntime gRPC server started" /tmp/ae-switchd.log 2>/dev/null' && break; sleep 3; done
ssh sw1 'pgrep -x bf_switchd >/dev/null' || { echo "FATAL switchd"; exit 1; }
sleep 2
ssh sw1 'cp /home/singtel/inho/fig10/port_add_jumbo.py /tmp/ae-port_add.py; tmux new-session -d -s bft "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /tmp/ae-port_add.py > /tmp/ae-bft.log 2>&1"' >/dev/null 2>&1
sleep 20
ssh sw1 'tmux kill-session -t bft 2>/dev/null; tmux new-session -d -s swset "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /tmp/ae-f12setup.py > /tmp/ae-swset.log 2>&1"' >/dev/null 2>&1
sleep 30
ssh sw1 'tmux kill-session -t swset 2>/dev/null; grep -c Traceback /tmp/ae-swset.log'
# ---- servers: 12 x http-server across node8/9/10 ----
for N in 8 9 10; do ssh node$N "sudo pkill -f http-server 2>/dev/null; sudo pkill -x dpdk-ctrl.elf 2>/dev/null; tmux kill-server 2>/dev/null; sudo rm -rf /var/run/dpdk/rte 2>/dev/null; true" >/dev/null 2>&1; done
sleep 2
for N in 8 9 10; do ssh node$N "tmux new-session -d -s dc$N \"cd $T && make PREFIX=/homes/inho dpdk-ctrl-node$N > /tmp/ae-dc$N.log 2>&1\"" >/dev/null 2>&1; done
sleep 22
for j in $(seq 0 11); do
  N=$((8 + j % 3)); CORE=$((j / 3 + 1)); PORT=$((10000 + j / 3))
  ssh node$N "tmux new-session -d -s sv$CORE \"cd $T && sudo -E env CORE_ID=$CORE CONFIG_PATH=$T/scripts/config/node${N}_config.yaml MTU=9000 MSS=9000 NUM_CORES=4 USE_JUMBO=1 LIBOS=catnip DATA_SIZE=256 LD_LIBRARY_PATH=\\/homes/inho/lib:\\/homes/inho/lib/x86_64-linux-gnu numactl -m0 timeout 3600 $T/bin/examples/rust/http-server.elf 10.0.1.$N:$PORT > /tmp/ae-sv${N}_$CORE.log 2>&1\"" >/dev/null 2>&1
done
sleep 6
UP=0; for N in 8 9 10; do C=$(ssh node$N "pgrep -fc 'http-server.elf 10'" 2>/dev/null); UP=$((UP + C)); done
echo "[$(date +%H:%M:%S)] fig12 bring-up done (server procs incl wrappers: $UP)"
