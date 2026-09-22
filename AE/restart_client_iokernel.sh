#!/bin/bash
# Start a fresh Caladan iokernel on a client node right before a runtime attaches.
#
#   bash ~/capybara-AE-runs/restart_client_iokernel.sh <5|6> <caladan tree>
#
# Why: node5 and node6 currently boot with SMT off, so their iokernel runs with
# `noht`. In that mode this Caladan build's iokernel can segfault when a second
# runtime attaches after a heavy one has exited (seen 2026-09-22 on node6 after a
# Fig 7 Capybara run). A fresh iokernel per measurement makes every attach a first
# attach, which is always fine. Costs ~7 s.
set -u
N=$1; TREE=$2
NOHT=$(ssh -o ConnectTimeout=8 node$N '[ "$(cat /sys/devices/system/cpu/smt/active 2>/dev/null)" = 1 ] || echo noht' 2>/dev/null)
LDP=""; [ "$N" = 5 ] && LDP="LD_LIBRARY_PATH=/homes/inho/lib"
ssh node$N "tmux kill-session -t iok$N 2>/dev/null; sudo pkill -x iokerneld 2>/dev/null; sleep 1; [ -e /dev/ksched ] || { sudo mknod /dev/ksched c 280 0; sudo chmod uga+rwx /dev/ksched; }; rm -f /tmp/ae-iok$N.log; tmux new-session -d -s iok$N \"cd $TREE && sudo $LDP ./iokerneld ias nicpci 0000:b3:00.0 nobw $NOHT > /tmp/ae-iok$N.log 2>&1\"" >/dev/null 2>&1
for i in $(seq 1 12); do
  ssh node$N "pgrep -x iokerneld >/dev/null && grep -q 'running dataplane' /tmp/ae-iok$N.log" 2>/dev/null && exit 0
  sleep 1
done
echo "iokerneld on node$N did not come up (see node$N:/tmp/ae-iok$N.log)"
exit 1
