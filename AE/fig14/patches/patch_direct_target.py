#!/usr/bin/env python3
"""Address the migration prepare message to the partner directly.

The paper-era stack (@4599b186, 2024-12-08) sent PREPARE to the partner server
itself — dest port literally `self==10001 ? 10000 : 10001` — and the switch only
forwarded it. The current stack instead sends it to SWITCH_IP for the switch to
retarget, which none of the installed programs do for our layout; the message
lands on the client node and dies.

The partner table for this exact experiment is already in the source, labelled
"TEMP: 2 servers for migration test (node8:10000 -> node9:10000)". This uses it:
pick the entry that is not ourselves.

Applies to the capybara-fig14 tree only.
"""
import os, shutil, sys

TREE = os.path.expanduser("/homes/inho/Capybara/capybara-fig14")
p = os.path.join(TREE, "src/rust/inetstack/protocols/tcpmig/peer.rs")
assert "capybara-fig14" in p, p

shutil.copy(p, p + ".pre-directtarget")
s = open(p).read()

old = """        // Always send PREPARE_MIG to switch - switch will decide the target
        capy_time_log!("INIT_MIG,({}),[{}->switch]", remote, local);

        let active = ActiveMigration::new(
            self.rt.clone(),
            self.local_ipv4_addr,
            self.local_link_addr,
            SWITCH_IP,
            SWITCH_MAC,
            self.self_udp_port,
            DEST_UDP_PORT,  // Switch UDP port
            local,
            remote,
            Some(qd),
            self.mtu,
        );"""
new = """        // Address the prepare to the partner server directly, as the stack did at
        // the paper's migration-latency runs: the two-entry backend table below
        // carries the partner's address and MAC, and the switch only forwards.
        let (target_mac, target_addr) = *self
            .backend_servers
            .iter()
            .find(|(_, a)| *a.ip() != self.local_ipv4_addr)
            .expect("no partner server in backend_servers");
        capy_time_log!("INIT_MIG,({}),[{}->switch]", remote, local);

        let active = ActiveMigration::new(
            self.rt.clone(),
            self.local_ipv4_addr,
            self.local_link_addr,
            *target_addr.ip(),
            target_mac,
            self.self_udp_port,
            target_addr.port(),
            local,
            remote,
            Some(qd),
            self.mtu,
        );"""
if old not in s:
    sys.exit("ANCHOR not found in initiate_migration")
s = s.replace(old, new, 1)

open(p, "w").write(s)
print("direct partner targeting installed in", p)
