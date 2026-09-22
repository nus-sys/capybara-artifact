#!/usr/bin/env python3
"""Trace the TLS context blob across the migration.

The target's tls_import_context returns null. These prints show the exported
size on the origin and the received length on the target, which tells us whether
the blob is truncated in flight or rejected whole.

capybara-fig14 only; reverted once the cause is known.
"""
import os, shutil, sys

p = os.path.expanduser("/homes/inho/Capybara/capybara-fig14/examples/rust/https.rs")
assert "capybara-fig14" in p
shutil.copy(p, p + ".pre-tlsdebug")
s = open(p).read()

old = """    fn migrate_in(remote: SocketAddrV4, buffer: Buffer) {
        let replaced = PEER.with_borrow_mut(|peer| peer.incoming.insert(remote, buffer));
        assert!(replaced.is_none())
    }"""
new = """    fn migrate_in(remote: SocketAddrV4, buffer: Buffer) {
        eprintln!("MIGDBG migrate_in len={}", buffer.len());
        let replaced = PEER.with_borrow_mut(|peer| peer.incoming.insert(remote, buffer));
        assert!(replaced.is_none())
    }"""
if old not in s: sys.exit("anchor1")
s = s.replace(old, new, 1)

old2 = """        let context = unsafe { tlse::tls_import_context(buf.as_ptr(), buf.len() as _) };"""
new2 = """        eprintln!("MIGDBG import len={} head={:?}", buf.len(), &buf[..buf.len().min(8)]);
        let context = unsafe { tlse::tls_import_context(buf.as_ptr(), buf.len() as _) };"""
if old2 not in s: sys.exit("anchor2")
s = s.replace(old2, new2, 1)

old3 = """        let size = unsafe { tlse::tls_export_context(self.0, null_mut(), 0, 1) };"""
new3 = """        let size = unsafe { tlse::tls_export_context(self.0, null_mut(), 0, 1) };
        eprintln!("MIGDBG export size={}", size);"""
if old3 not in s: sys.exit("anchor3")
s = s.replace(old3, new3, 1)

open(p, "w").write(s)
print("tls blob tracing installed")
