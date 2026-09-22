#!/usr/bin/env python3
"""Route the prepare like every other migration message.

initiate_migration() forced the prepare through send_via_switch(), which ignores
the target the ActiveMigration was built with and hardcodes SWITCH_IP — so the
message went to the client node regardless of the partner targeting. send() is
the path the rest of the protocol uses: direct to the target, via the switch
only when origin and target share an address.

Applies to the capybara-fig14 tree only.
"""
import os, shutil, sys

p = os.path.expanduser("/homes/inho/Capybara/capybara-fig14/src/rust/inetstack/protocols/tcpmig/active.rs")
assert "capybara-fig14" in p
shutil.copy(p, p + ".pre-senddirect")
s = open(p).read()

old = """        capy_time_log!("SEND_PREPARE_MIG,({}),[{}->{}:{}](via switch)", self.client, self.origin, self.remote_ipv4_addr, self.dest_udp_port);
        self.send_via_switch(tcpmig_hdr, Buffer::Heap(DataBuffer::empty()));"""
new = """        capy_time_log!("SEND_PREPARE_MIG,({}),[{}->{}:{}](via switch)", self.client, self.origin, self.remote_ipv4_addr, self.dest_udp_port);
        self.send(tcpmig_hdr, Buffer::Heap(DataBuffer::empty()));"""
if old not in s:
    sys.exit("ANCHOR not found")
open(p, "w").write(s.replace(old, new, 1))
print("prepare now routed like the rest of the protocol")
