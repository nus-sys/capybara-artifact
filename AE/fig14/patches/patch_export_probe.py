#!/usr/bin/env python3
"""Probe the failing export precondition.

tlse refuses to export unless the context is established, exportable, and has
retained its keys. Printing tls_established at export time splits the failure:
0 means the context handed to migrate_out is not the handshaked one (lifecycle),
1 means the exportable keys were never retained (make_exportable timing or TLS
version support).
"""
import os, shutil, sys
p = os.path.expanduser("/homes/inho/Capybara/capybara-fig14/examples/rust/https.rs")
shutil.copy(p, p + ".pre-exportprobe")
s = open(p).read()
old = """        let size = unsafe { tlse::tls_export_context(self.0, null_mut(), 0, 1) };
        eprintln!("MIGDBG export size={}", size);"""
new = """        let size = unsafe { tlse::tls_export_context(self.0, null_mut(), 0, 1) };
        eprintln!("MIGDBG export size={} established={}", size, unsafe { tlse::tls_established(self.0) });"""
if old not in s: sys.exit("anchor")
open(p, "w").write(s.replace(old, new, 1))
print("export probe installed")
