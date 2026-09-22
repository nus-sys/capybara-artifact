#!/bin/bash
# ============================================================================
# Fig. 14 reproduction — migration latency by connection state size, BOTH panels
#   Run on node7:  bash ~/capybara-AE-runs/fig14/run_fig14.sh
#   ~30 min: five state sizes x 2,000 measured migrations per panel (TCP, TLS)
#   -> stacked-bar figure beside the paper's own data files -> restore.
#
# Platform is the paper's own tree (monorepo @4599b186, the commit the day
# before the paper's runs) in /homes/inho/Capybara/capybara-fig14tls. Both backends run on
# node8 — the FRONTEND_IP host — so every phase timestamp shares one clock and
# the prepare hairpins through the port_forward baseline. The TLS client is held
# to TLS 1.2 (tlse cannot take a 1.3 ClientHello) via OPENSSL_CONF.
# ============================================================================
set -u
D=~/capybara-AE-runs/fig14
step(){ echo "[$(date +%H:%M:%S)] $*"; }

cleanup(){
  step "Cleanup"
  bash ~/capybara-AE-runs/cleanup_all.sh
}
trap cleanup EXIT
bash ~/capybara-AE-runs/arm_watchdog.sh 5400 >/dev/null 2>&1

step "Client node7: restore reboot-cleared prerequisites (NIC link up, sysctls)"
bash ~/capybara-AE-runs/prepare_nodes.sh 7 || { echo "FATAL: node7 not ready (see above)"; exit 1; }

step "Client path: node7 kernel on the data network"
sudo ip link set ens85f1np1 up
ip addr show ens85f1np1 | grep -q "10.0.1.7/24" || sudo ip addr add 10.0.1.7/24 dev ens85f1np1
sudo ip neigh replace 10.0.1.8 lladdr 08:c0:eb:b6:e8:05 dev ens85f1np1
sudo ip neigh replace 10.0.1.9 lladdr 08:c0:eb:b6:c5:ad dev ens85f1np1
cp $D/tls12.cnf /tmp/ae-tls12.cnf

step "Switch: port_forward baseline"
ssh sw1 'pgrep -x bf_switchd >/dev/null' || { step "  baseline not up - restoring"; bash ~/capybara-AE-runs/cleanup_all.sh; }

rm -f $D/fig14_tcp_results.txt $D/fig14_tls_results.txt
for KB in 0 16 32 64 128; do
  SZ=$((KB*1024))
  step "TCP panel, ${KB} KB"
  RT=15 bash $D/run_miglat_tcp2.sh $SZ sweep 2>&1 | tail -1
  python3 $D/parse_miglat.py miglattcp2-${SZ}-sweep 2>&1 | tail -3 | tee -a $D/fig14_tcp_results.txt
done
for KB in 0 16 32 64 128; do
  SZ=$((KB*1024))
  step "TLS panel, ${KB} KB"
  RT=15 bash $D/run_miglat_tls2.sh $SZ sweep 2>&1 | tail -1
  python3 $D/parse_miglat.py miglattls${SZ}-sweep 2>&1 | tail -3 | tee -a $D/fig14_tls_results.txt
done

step "Figure"
cd $D && python3 /homes/sigcomm26ae/capybara-AE-runs/paperplot/paper_style.py fig14 $HOME/capybara-data $D/paper_ref $D/fig14_reproduction
step "DONE. Figure: $D/fig14_reproduction.png (+ .pdf)"
