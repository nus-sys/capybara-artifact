#!/bin/bash
# Measure per-hop packet counter deltas across one fig10 run.
# usage: hop_loss.sh <COND> <SIZE> <RPS>
C=$1; S=$2; R=$3
snap(){
  echo "n7tx $(ethtool -S ens85f1np1 | grep -oE 'tx_packets_phy: [0-9]+' | grep -oE '[0-9]+$')"
  echo "n7rx $(ethtool -S ens85f1np1 | grep -oE 'rx_packets_phy: [0-9]+' | grep -oE '[0-9]+$')"
  echo "n6tx $(ssh node6 "ethtool -S enp179s0 | grep -oE 'tx_packets_phy: [0-9]+' | grep -oE '[0-9]+\$'" 2>/dev/null)"
  for N in 8 9 10; do
    echo "n${N}rx $(ssh node$N "ethtool -S ens85f1np1 | grep -oE 'rx_packets_phy: [0-9]+' | grep -oE '[0-9]+\$'" 2>/dev/null)"
    echo "n${N}disc $(ssh node$N "ethtool -S ens85f1np1 | grep -oE 'rx_discards_phy: [0-9]+' | grep -oE '[0-9]+\$'" 2>/dev/null)"
    echo "n${N}oob $(ssh node$N "ethtool -S ens85f1np1 | grep -oE 'rx_out_of_buffer: [0-9]+' | grep -oE '[0-9]+\$'" 2>/dev/null)"
    echo "n${N}miss $(ssh node$N "ethtool -S ens85f1np1 | grep -oE 'rx_steer_missed_packets: [0-9]+' | grep -oE '[0-9]+\$'" 2>/dev/null)"
  done
}
snap > /tmp/ae-hop_before.txt
bash ~/capybara-AE-runs/fig10/run_fig10_one.sh $C $S $R 2>&1 | tail -1
snap > /tmp/ae-hop_after.txt
echo "=== per-hop deltas ==="
join /tmp/ae-hop_before.txt /tmp/ae-hop_after.txt | awk '{d=$3-$2; if (d!=0) printf "%-8s %12d\n", $1, d}'
