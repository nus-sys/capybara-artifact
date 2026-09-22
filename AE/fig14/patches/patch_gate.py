#!/usr/bin/env python3
"""Only migrate an actually-established TLS session.

tls_established returns -1 when the context has hit a critical error; the
migrate gate tested != 0 and so migrated broken sessions, whose contexts tlse
then rightly refuses to export. Gate on == 1.
"""
import os, shutil, sys
p = os.path.expanduser("/homes/inho/Capybara/capybara-fig14/examples/rust/https.rs")
shutil.copy(p, p + ".pre-gate")
s = open(p).read()
old = "                    if unsafe { tlse::tls_established(context) } != 0 {"
new = "                    if unsafe { tlse::tls_established(context) } == 1 {"
if old not in s: sys.exit("anchor")
open(p, "w").write(s.replace(old, new, 1))
print("gate fixed")
