#!/usr/bin/env python3
"""Same-host layout, single clock.

The phase intervals are computed from timestamps taken on both endpoints, so the
two backends must share a clock — which is why the paper ran both on node9. The
partner table goes back to the two node9 ports, a server identifies itself by the
connection's listen port, and the same-address send path delivers directly by
MAC (an L2 hairpin through the switch) instead of detouring via SWITCH_IP.
"""
import os, shutil, sys

pp = os.path.expanduser("/homes/inho/Capybara/capybara-fig14/src/rust/inetstack/protocols/tcpmig/peer.rs")
shutil.copy(pp, pp + ".pre-samehost")
s = open(pp).read()

old = """        let backend_servers = arrayvec::ArrayVec::from([
            (NODE9_MAC, SocketAddrV4::new(Ipv4Addr::new(10, 0, 1, 9), 10000)),
            (NODE8_MAC, SocketAddrV4::new(Ipv4Addr::new(10, 0, 1, 8), 10000)),
        ]);"""
new = """        let backend_servers = arrayvec::ArrayVec::from([
            (NODE9_MAC, SocketAddrV4::new(Ipv4Addr::new(10, 0, 1, 9), 10000)),
            (NODE9_MAC, SocketAddrV4::new(Ipv4Addr::new(10, 0, 1, 9), 10001)),
        ]);"""
if old not in s: sys.exit("anchor table")
s = s.replace(old, new, 1)

old2 = """        let (target_mac, target_addr) = *self
            .backend_servers
            .iter()
            .find(|(_, a)| *a.ip() != self.local_ipv4_addr)
            .expect("no partner server in backend_servers");"""
new2 = """        let (target_mac, target_addr) = *self
            .backend_servers
            .iter()
            .find(|(_, a)| !(*a.ip() == *local.ip() && a.port() == local.port()))
            .expect("no partner server in backend_servers");"""
if old2 not in s: sys.exit("anchor find")
s = s.replace(old2, new2, 1)
open(pp, "w").write(s)

pa = os.path.expanduser("/homes/inho/Capybara/capybara-fig14/src/rust/inetstack/protocols/tcpmig/active.rs")
shutil.copy(pa, pa + ".pre-samehost")
s = open(pa).read()
old3 = """        } else if self.remote_ipv4_addr == self.local_ipv4_addr {
            // Same IP: route via switch
            capy_log_mig!("[SEND] Same IP, routing via switch: {} -> {}", self.remote_ipv4_addr, SWITCH_IP);
            (SWITCH_IP, SWITCH_MAC)
        } else {"""
new3 = """        } else if false {
            // Same-address targets are delivered directly by MAC: the switch
            // hairpins the frame back out the same port.
            (SWITCH_IP, SWITCH_MAC)
        } else {"""
if old3 not in s: sys.exit("anchor sameip")
open(pa, "w").write(s.replace(old3, new3, 1))
print("same-host layout installed")
