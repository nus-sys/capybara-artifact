#!/bin/bash
# Restore the client-node state that a reboot clears, so a runner never starts on
# a half-prepared cluster. Idempotent and safe to run at any time, from node7:
#
#   bash ~/capybara-AE-runs/prepare_nodes.sh          # node7, node6, node5
#   bash ~/capybara-AE-runs/prepare_nodes.sh 7 6      # a subset
#
# Every runner calls this first. What it restores, per client node:
#   - the iokernel sysctls (shared memory, hugetlb group, map count)
#   - the ksched kernel module and /dev/ksched (picked by the running kernel)
#   - the msr module
#   - hugepages (node5/6: 5192 on node0; node7 keeps its boot default 1568/9216)
#   - the data-plane NIC link up, with its 10.0.1.x address
# Server nodes (8/9/10) need nothing: dpdk-ctrl owns their NIC and their hugepages
# persist across boots.
set -u
NODES="${*:-7 6 5}"
KO_DIR=/homes/inho/Capybara/ksched-builds     # one ksched.ko per kernel release

# ---- the per-node routine, run locally on each node (via ssh for 5/6) ----------
read -r -d '' PREP <<'EOF'
set -u
N=$(hostname | sed 's/.*node//')
KREL=$(uname -r)
KO_DIR=__KO_DIR__
case $N in
  7) NIC=ens85f1np1;  IP=10.0.1.7; FALLBACK=/homes/inho/Capybara/caladan/ksched/build/ksched.ko ;;
  6) NIC=enp179s0;    IP=10.0.1.6; FALLBACK=/homes/inho/Capybara/caladan-n6/ksched/build/ksched.ko ;;
  5) NIC=enp179s0np0; IP=10.0.1.5; FALLBACK=/homes/inho/Capybara/caladan-fig8-n6/ksched/build/ksched.ko ;;
  *) echo "node$N: not a client node"; exit 0 ;;
esac

sudo sysctl -q -w kernel.shm_rmid_forced=1 kernel.shmmax=18446744073692774399 \
  vm.hugetlb_shm_group=27 vm.max_map_count=16777216 net.core.somaxconn=3072
sudo modprobe msr 2>/dev/null

# ksched: a module built for exactly this kernel
if ! lsmod | grep -q '^ksched'; then
  KO=$KO_DIR/$KREL/ksched.ko
  [ -f "$KO" ] || KO=$FALLBACK
  if [ -f "$KO" ] && [ "$(modinfo -F vermagic "$KO" | cut -d' ' -f1)" = "$KREL" ]; then
    sudo insmod "$KO"
  else
    echo "node$N: NO ksched.ko for kernel $KREL (looked in $KO_DIR/$KREL and $FALLBACK)"
    echo "node$N: build one (out of tree, on this node):  mkdir -p $KO_DIR/$KREL/build && cd /homes/inho/Capybara/caladan-fig8-n6/ksched && make BUILD_DIR=$KO_DIR/$KREL/build BUILD_DIR_MAKEFILE=$KO_DIR/$KREL/build/Makefile && cp $KO_DIR/$KREL/build/ksched.ko $KO_DIR/$KREL/"
    exit 1
  fi
fi
[ -e /dev/ksched ] || sudo mknod /dev/ksched c 280 0
sudo chmod uga+rwx /dev/ksched

# hugepages: node7 keeps its boot layout (node0 1568 / node1 9216, managed by the
# fig10 runner and cleanup_all.sh); node5/6 get the caladan default on node0
if [ "$N" != 7 ]; then
  cur=$(cat /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages)
  [ "$cur" -ge 5192 ] || echo 5192 | sudo tee /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages >/dev/null
fi

# data-plane NIC: link up, address present
sudo ip link set "$NIC" up
ip addr show "$NIC" | grep -q "$IP/24" || sudo ip addr add "$IP/24" dev "$NIC"

# the link needs a few seconds after a switch program change; DPDK clients do not
# need it UP here (the PMD brings it up), but the kernel-path figures (11, 14) do
for i in 1 2 3 4 5 6 7 8; do
  [ "$(ip -br link show "$NIC" | awk '{print $2}')" = UP ] && break; sleep 1
done
printf "node%s ok: kernel=%s ksched=%s hugepages=%s nic=%s %s\n" "$N" "$KREL" \
  "$(lsmod | grep -c '^ksched')" \
  "$(cat /sys/devices/system/node/node*/hugepages/hugepages-2048kB/nr_hugepages | paste -sd/)" \
  "$NIC" "$(ip -br link show "$NIC" | awk '{print $2}')"
EOF
PREP=${PREP//__KO_DIR__/$KO_DIR}

rc=0
for N in $NODES; do
  if [ "$N" = "$(hostname | sed 's/.*node//')" ]; then
    bash -c "$PREP" || rc=1
  else
    ssh -o ConnectTimeout=8 node$N "bash -s" <<<"$PREP" || rc=1
  fi
done
[ $rc = 0 ] || echo "prepare_nodes: a client node is not ready (see above)"
exit $rc
