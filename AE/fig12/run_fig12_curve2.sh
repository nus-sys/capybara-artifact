#!/bin/bash
# Fig12 curve 2 (Capybara-Switch: connections migrated during the run) ladder.
# Same 12-process wrk2 driving as curve 1, but the switch runs the src-rewriting
# migration program (seeded min-workload) and the servers migrate on a MIG_PER_N
# time gate. With MIG_PER_N ~ run duration each conn migrates ~once (the paper's
# "migrated once" semantics); curve 2 should track curve 1 (no datapath cost).
# usage: run_fig12_curve2.sh "<per-proc conn list>" <MIG_PER_N_us> [dur]
set -u
CONNS=${1:-"1200"}; MIGN=${2:-10000000}; DUR=${3:-20}
T=/homes/inho/Capybara/capybara-fig12
OUT=~/capybara-AE-runs/fig12/results_fig12_curve2.txt
D=~/capybara-AE-runs/fig12/raw_c2
mkdir -p $D
step(){ echo "[$(date +%H:%M:%S)] $*"; }

bringup_switch(){
  ssh sw1 'for s in sw bft swset pktgen baseline blcfg; do tmux kill-session -t $s 2>/dev/null; done; sudo pkill -x bf_switchd 2>/dev/null; true' >/dev/null 2>&1
  sleep 2
  ssh sw1 'rm -f /tmp/ae-switchd.log; tmux new-session -d -s sw "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_switchd.sh -p capybara_switch_fe_src_rewriting_by_server > /tmp/ae-switchd.log 2>&1"' >/dev/null 2>&1
  for i in $(seq 1 30); do ssh sw1 'grep -q "bfruntime gRPC server started" /tmp/ae-switchd.log 2>/dev/null' && break; sleep 3; done
  ssh sw1 'pgrep -x bf_switchd >/dev/null' || { echo "FATAL switchd"; exit 1; }
  sleep 3
  ssh sw1 'cp /home/singtel/inho/fig10/port_add_jumbo.py /tmp/ae-port_add.py; tmux new-session -d -s bft "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /tmp/ae-port_add.py > /tmp/ae-bft.log 2>&1"' >/dev/null 2>&1
  sleep 22
  # rebuild the seeded setup fresh each bring-up (era head -389 + min-workload seed)
  scp -o ConnectTimeout=8 ~/capybara-AE-runs/fig12/build_f12setup.sh sw1:/tmp/ae-build_f12setup.sh >/dev/null 2>&1
  ssh sw1 'bash /tmp/ae-build_f12setup.sh >/dev/null 2>&1; tmux kill-session -t bft 2>/dev/null; tmux new-session -d -s swset "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /tmp/ae-f12setup.py > /tmp/ae-swset.log 2>&1"' >/dev/null 2>&1
  sleep 30
  step "swset traceback: $(ssh sw1 'grep -c Traceback /tmp/ae-swset.log' 2>/dev/null); seed ok: $(ssh sw1 'grep -c "min-workload seed applied" /tmp/ae-swset.log' 2>/dev/null)"
  ssh sw1 'tmux kill-session -t swset 2>/dev/null; tmux new-session -d -s pktgen "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_pd_rpc-9.2.0.py -d asic /home/singtel/inho/fig8/main_eval_pktgen_timer_1ms.py -i > /tmp/ae-pktgen.log 2>&1"' >/dev/null 2>&1
  sleep 12
}

start_mig_servers(){
  for N in 8 9 10; do ssh node$N "sudo pkill -f http-server 2>/dev/null; sudo pkill -x dpdk-ctrl.elf 2>/dev/null; tmux kill-server 2>/dev/null; sudo rm -rf /var/run/dpdk/rte 2>/dev/null; true" >/dev/null 2>&1; done
  sleep 2
  for N in 8 9 10; do ssh node$N "tmux new-session -d -s dc$N \"cd $T && make PREFIX=/homes/inho dpdk-ctrl-node$N > /tmp/ae-dc$N.log 2>&1\"" >/dev/null 2>&1; done
  sleep 22
  for j in $(seq 0 11); do
    N=$((8 + j % 3)); CORE=$((j / 3 + 1)); PORT=$((10000 + j / 3))
    ssh node$N "tmux new-session -d -s sv$CORE \"cd $T && sudo -E env MIG_PER_N=$MIGN CORE_ID=$CORE CONFIG_PATH=$T/scripts/config/node${N}_config.yaml MTU=9000 MSS=9000 NUM_CORES=4 USE_JUMBO=1 LIBOS=catnip DATA_SIZE=256 LD_LIBRARY_PATH=\\/homes/inho/lib:\\/homes/inho/lib/x86_64-linux-gnu numactl -m0 timeout 300 $T/bin/examples/rust/http-server.elf 10.0.1.$N:$PORT > /tmp/ae-sv${N}_$CORE.log 2>&1\"" >/dev/null 2>&1
  done
  sleep 8
}

bringup_switch
for C in $CONNS; do
  start_mig_servers
  CODE=$(timeout 8 curl -s -o /dev/null -w "%{http_code}" http://10.0.1.8:55555/get)
  if [ "$CODE" != "200" ]; then echo "RES fig12 curve2 conn=$((C*12)) mign=$MIGN SANITY-FAIL" | tee -a $OUT; continue; fi
  ID="c2-c$C-m$MIGN"; rm -f $D/$ID.*
  for CL in 5 6 7; do
    for i in 0 1 2 3; do
      SP=$((1024 + 16128 * i)); SC=$((i * 10)); EC=$((SC + 9))
      CMD="taskset -c $SC-$EC sudo numactl -m0 /homes/inho/wrk-tools/wrk2/wrk -t10 -c$C -P$SP-$((SP + C - 1)) -d${DUR}s -R200000 http://10.0.1.8:55555/get > $D/$ID.node$CL.p$i 2>&1"
      if [ "$CL" = "7" ]; then tmux new-session -d -s w$i "$CMD"; else ssh node$CL "tmux new-session -d -s w$i \"$CMD\"" >/dev/null 2>&1 & fi
    done
  done
  wait
  sleep $((DUR + 25))
  for CL in 5 6; do ssh node$CL "sudo pkill -x wrk 2>/dev/null; true" >/dev/null 2>&1; done; sudo pkill -x wrk 2>/dev/null
  TOT=$(grep -h "Requests/sec" $D/$ID.* 2>/dev/null | awk "{s+=\$2} END {printf \"%.0f\", s}")
  NPROC=$(grep -lh "Requests/sec" $D/$ID.* 2>/dev/null | wc -l)
  echo "RES fig12 curve2 conn=$((C*12)) mign=$MIGN total_rps=${TOT:-0} procs=$NPROC" | tee -a $OUT
done
