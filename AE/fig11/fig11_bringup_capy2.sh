#!/bin/bash
# Fig11 capy-proxy bring-up, era-faithful: the LIVE-tree capybara_switch_fe program
# (SYN round-robin straight to the node9 backends; reply src-rewrite masks them as
# 10.0.1.8:55555; every tcpmig message is retargeted to node9, and egress rewrites
# each PREPARE's dst port to the min-RPS backend port, which the pktgen-driven RPS
# machinery keeps current). Setup = the exact script run_eval.py invoked.
# The NUM_BE overlay rewrites the 16 backend_port slots to 10000+(i % NB).
# usage: fig11_bringup_capy2.sh [num_be]
NB=${1:-1}
ssh sw1 'for s in sw bft swset swov swov2 pktgen baseline blcfg rdr p4b; do tmux kill-session -t $s 2>/dev/null; done; sudo pkill -x bf_switchd 2>/dev/null; true' >/dev/null 2>&1
sleep 2
ssh sw1 'rm -f /tmp/ae-switchd.log; tmux new-session -d -s sw "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_switchd.sh -p capybara_switch_fe > /tmp/ae-switchd.log 2>&1"' >/dev/null 2>&1
for i in $(seq 1 30); do ssh sw1 'grep -q "bfruntime gRPC server started" /tmp/ae-switchd.log 2>/dev/null' && break; sleep 3; done
ssh sw1 'pgrep -x bf_switchd >/dev/null' || { echo "FATAL switchd"; exit 1; }
sleep 2
ssh sw1 'cp /home/singtel/inho/fig10/port_add_jumbo.py /tmp/ae-port_add.py; tmux new-session -d -s bft "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /tmp/ae-port_add.py > /tmp/ae-bft.log 2>&1"' >/dev/null 2>&1
sleep 20
ssh sw1 'tmux kill-session -t bft 2>/dev/null; tmux new-session -d -s swset "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /home/singtel/inho/Capybara/capybara/p4/switch_fe/capybara_switch_fe_setup.py > /tmp/ae-swset.log 2>&1"' >/dev/null 2>&1
sleep 30
ssh sw1 "cat > /tmp/ae-nbov.py <<PYEOF
p4 = bfrt.capybara_switch_fe.pipe
NB = $NB
for i in range(16):
    p4.Ingress.backend_port.mod(REGISTER_INDEX=i, f1=10000 + (i % NB))
# The min-RPS poll multicasts one rps_signal copy per backend; restrict the
# group to the NB live backends or a dead port can win the tie and swallow
# every PREPARE.
ids = [10000 + i for i in range(NB)]
try:
    bfrt.pre.mgid.mod(MGID=2, MULTICAST_NODE_ID=ids,
        MULTICAST_NODE_L1_XID_VALID=[False]*NB, MULTICAST_NODE_L1_XID=[0]*NB)
except Exception:
    bfrt.pre.mgid.delete(MGID=2)
    bfrt.pre.mgid.entry(MGID=2, MULTICAST_NODE_ID=ids,
        MULTICAST_NODE_L1_XID_VALID=[False]*NB, MULTICAST_NODE_L1_XID=[0]*NB).push()
bfrt.complete_operations()
print(\"NB_OVERLAY_DONE\")
PYEOF
tmux kill-session -t swset 2>/dev/null; tmux new-session -d -s swov \"source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_bfshell.sh -b /tmp/ae-nbov.py > /tmp/ae-swov.log 2>&1\"" >/dev/null 2>&1
sleep 22
ssh sw1 'tmux kill-session -t swov 2>/dev/null; grep -c NB_OVERLAY_DONE /tmp/ae-swov.log; grep -c Traceback /tmp/ae-swset.log /tmp/ae-swov.log | paste -sd" "'
ssh sw1 'tmux kill-session -t pktgen 2>/dev/null; tmux new-session -d -s pktgen "source /home/singtel/tools/set_sde.bash; /home/singtel/bf-sde-9.4.0/run_pd_rpc-9.2.0.py -d asic /home/singtel/inho/Capybara/capybara/p4/switch_fe/capybara_switch_fe_pktgen_timer.py -i > /tmp/ae-pktgen.log 2>&1"' >/dev/null 2>&1
sleep 8
ssh sw1 'grep -ciE "error|Traceback" /tmp/ae-pktgen.log; echo pktgen-started'
echo "[$(date +%H:%M:%S)] bring-up2 done (NUM_BE=$NB)"
