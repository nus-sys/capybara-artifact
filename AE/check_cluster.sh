#!/bin/bash
# Read-only preflight: is the testbed in the state the runners expect?
#
#   bash ~/capybara-AE-runs/check_cluster.sh
#
# Prints one line per check (OK / WARN / FAIL) and exits non-zero on FAIL. Safe at
# any time; it changes nothing. Run it before your first experiment, or whenever a
# runner behaves unexpectedly. WARNs are fixed by the runners themselves
# (prepare_nodes.sh runs first in every one); FAILs need the authors.
set -u
rc=0
ok(){ echo "OK    $*"; }; warn(){ echo "WARN  $*"; }; fail(){ echo "FAIL  $*"; rc=1; }

# 1. reachability + sudo on every node and the switch
for h in node5 node6 node8 node9 node10 sw1; do
  out=$(ssh -o BatchMode=yes -o ConnectTimeout=6 $h 'sudo -n true 2>/dev/null && echo sudo-ok || echo sudo-NO' 2>/dev/null)
  case "$out" in
    sudo-ok) ok "$h reachable, sudo ok" ;;
    sudo-NO) fail "$h reachable but no passwordless sudo" ;;
    *)       fail "$h unreachable" ;;
  esac
done
sudo -n true 2>/dev/null && ok "node7 sudo ok" || fail "node7: no passwordless sudo"

# 2. nothing left running from a previous experiment
busy=""
pgrep -x synthetic >/dev/null && busy="$busy node7:synthetic"
pgrep -x iokerneld >/dev/null && busy="$busy node7:iokerneld"
pgrep -x capybara-switch >/dev/null && busy="$busy node7:capybara-switch"
for n in 5 6; do ssh -o BatchMode=yes node$n 'pgrep -x synthetic >/dev/null || pgrep -x iokerneld >/dev/null' 2>/dev/null && busy="$busy node$n:client"; done
for n in 8 9 10; do ssh -o BatchMode=yes node$n "pgrep -x http-server.elf >/dev/null || { [ $n = 9 ] && pgrep -x redis-server >/dev/null; } || pgrep -x dpdk-ctrl.elf >/dev/null" 2>/dev/null && busy="$busy node$n:server"; done
for n in 8 9; do ssh -o BatchMode=yes node$n "pgrep -x proxy-server-fe >/dev/null || pgrep -x proxy-server-be >/dev/null || pgrep -x prism-fe.elf >/dev/null || pgrep -x prism-be-http.e >/dev/null || pgrep -x capy-proxy-fe.e >/dev/null || pgrep -x capy-proxy-be.e >/dev/null" 2>/dev/null && busy="$busy node$n:fig11-L7"; done
[ -z "$busy" ] && ok "no experiment processes running" || warn "leftover processes:$busy  -> bash ~/capybara-AE-runs/cleanup_all.sh"

# 3. switch on the idle baseline
prog=$(ssh -o BatchMode=yes sw1 'pgrep -a bf_switchd | grep -oE "tofino/[a-z_0-9]+\.conf"' 2>/dev/null | head -1)
case "$prog" in
  tofino/port_forward.conf) ok "switch: port_forward baseline" ;;
  "")                       warn "switch: no switchd running (runners start their own program)" ;;
  *)                        warn "switch: running $prog, not the baseline -> cleanup_all.sh restores it" ;;
esac

# 3b. switch-host kernel modules that a reboot of sw1 loses (prepare_nodes.sh reloads them)
mods=$(ssh -o BatchMode=yes -o ConnectTimeout=6 sw1 'lsmod | grep -cE "^(bf_kpkt|i2c_i801) "' 2>/dev/null)
[ "${mods:-0}" = 2 ] && ok "sw1 kernel modules bf_kpkt + i2c_i801 loaded" || warn "sw1 kernel modules missing (${mods:-0}/2 of bf_kpkt, i2c_i801; prepare_nodes.sh loads them, else no port comes up)"

# 4. client-node prerequisites (what prepare_nodes.sh restores)
chk_client(){ # node nic
  local n=$1 nic=$2 out
  out=$(ssh -o BatchMode=yes -o ConnectTimeout=6 node$n "printf '%s %s %s %s %s %s %s %s' \$(lsmod | grep -c '^ksched') \$(cat /sys/devices/system/cpu/smt/active 2>/dev/null || echo 1) \$(cat /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages) \$(ip -br link show $nic 2>/dev/null | awk '{print \$2}') \$(sysctl -n kernel.shm_rmid_forced) \$(nproc) \$(awk '/MemTotal/{printf \"%d\", \$2/1048576}' /proc/meminfo) \$(cat /sys/class/net/$nic/mtu 2>/dev/null || echo 0)" 2>/dev/null)
  set -- $out
  [ "${1:-0}" = 1 ] && ok "node$n ksched loaded" || warn "node$n ksched not loaded (prepare_nodes.sh loads it)"
  [ "${2:-1}" = 1 ] && ok "node$n SMT on" || warn "node$n SMT off (prepare_nodes.sh re-enables it; else noht fallback)"
  [ "${3:-0}" -ge 1000 ] && ok "node$n hugepages ${3}" || warn "node$n hugepages ${3:-0} (prepare_nodes.sh reserves them)"
  [ "${4:-}" = UP ] && ok "node$n data NIC $nic UP" || warn "node$n data NIC $nic ${4:-?} (prepare_nodes.sh brings it up)"
  [ "${5:-0}" = 1 ] && ok "node$n iokernel sysctls set" || warn "node$n iokernel sysctls unset (prepare_nodes.sh sets them)"
  if [ "$n" != 7 ]; then
    { [ "${6:-0}" -ge 16 ] && [ "${7:-0}" -ge 32 ]; } && ok "node$n shape ${6} CPUs / ${7} GB" || fail "node$n booted with a reduced shape (${6:-?} CPUs / ${7:-?} GB) - cannot drive load; needs a reboot with its full configuration"
  fi
  [ "${8:-0}" -ge 9000 ] && ok "node$n data NIC MTU ${8}" || warn "node$n data NIC MTU ${8:-?} (prepare_nodes.sh sets 9000; jumbo responses need it)"
}
chk_client 7 ens85f1np1; chk_client 6 enp179s0; chk_client 5 enp179s0np0
for n in 5 6; do
  krel=$(ssh -o BatchMode=yes node$n uname -r 2>/dev/null)
  if ssh -o BatchMode=yes node$n "lsmod | grep -q '^ksched'" 2>/dev/null; then :; else
    ko=/homes/inho/Capybara/ksched-builds/$krel/ksched.ko
    ssh -o BatchMode=yes node$n "[ -f $ko ] || modinfo -F vermagic /homes/inho/Capybara/caladan-n6/ksched/build/ksched.ko 2>/dev/null | grep -q '^$krel '" 2>/dev/null \
      && ok "node$n has a ksched build for $krel" || fail "node$n kernel $krel has no ksched build (see prepare_nodes.sh output)"
  fi
done

# 5. server hugepages
for n in 8 9 10; do
  hp=$(ssh -o BatchMode=yes node$n 'grep HugePages_Total /proc/meminfo | awk "{print \$2}"' 2>/dev/null)
  [ "${hp:-0}" -ge 4096 ] && ok "node$n hugepages $hp" || fail "node$n hugepages ${hp:-0} (servers need DPDK hugepages)"
done

# 6. the trees and binaries the runners execute
miss=""
for p in /homes/inho/Capybara/capybara/bin/examples/rust/http-server.elf /homes/inho/Capybara/capybara-fig8/bin/examples/rust/http-server.elf \
         /homes/inho/Capybara/capybara-fig10/bin/examples/rust/http-server.elf /homes/inho/Capybara/capybara-fig14tls/bin/examples/rust/https.elf \
         /homes/inho/Capybara/caladan/iokerneld /homes/inho/Capybara/caladan-n6/iokerneld /homes/inho/Capybara/caladan-fig8/iokerneld \
         /homes/inho/Capybara/caladan-fig8-n6/iokerneld /homes/inho/Capybara/capybara-redis/src/redis-server /homes/inho/wrk-tools/wrk/wrk; do
  [ -x "$p" ] || miss="$miss $p"
done
[ -z "$miss" ] && ok "all runner binaries present" || fail "missing/unreadable binaries:$miss"
for p in /home/singtel/tools/set_sde.bash /home/singtel/tools/run_pd_rpc.py /home/singtel/bf-sde-9.4.0/run_switchd.sh /home/singtel/inho/fig8/main_eval_fig8_setup.py /home/singtel/inho/fig10/main_eval_fig10_setup.py; do
  ssh -o BatchMode=yes sw1 "[ -r $p ]" 2>/dev/null || { fail "sw1: $p unreadable"; }
done
ok "switch-side scripts readable"

# 7. plotting
python3 -c "import sys; sys.path.insert(0,'$HOME/capybara-AE-runs/paperplot'); import paper_style, pandas, matplotlib, brokenaxes" 2>/dev/null \
  && ok "plotting dependencies importable" || fail "plotting dependencies missing (see requirements.txt)"

[ $rc = 0 ] && echo "RESULT: cluster ready" || echo "RESULT: FAIL above needs the authors — please tell us in the HotCRP thread"
exit $rc
