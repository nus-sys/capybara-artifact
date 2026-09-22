#!/usr/bin/env python3
"""Flip http-server into the paper's migration-latency mode.

The source ships both modes behind paired markers in the accept arm: the normal
block registers per-connection state and is marked COMMENT OUT for this eval,
and the eval block — migrate on every accept, bounded at 11,000 — is marked
ACTIVATE. The connection then ping-pongs on its own: each accept at the new
host re-initiates, the popped request returns ETCPMIG (already handled), and the
synthetic state comes from CONFIGURED_STATE_SIZE in the stack.

capybara-fig14 only.
"""
import os, re, shutil, sys

p = os.path.expanduser("/homes/inho/Capybara/capybara-fig14/examples/rust/http-server.rs")
assert "capybara-fig14" in p
shutil.copy(p, p + ".pre-migdelay-eval")
s = open(p).read()

CM = "/* COMMENT OUT THIS FOR APP_STATE_SIZE VS MIG_LAT EVAL */"
AM = "/* ACTIVATE THIS FOR APP_STATE_SIZE VS MIG_LAT EVAL */"
assert s.count(CM) == 2, s.count(CM)
assert s.count(AM) == 2, s.count(AM)

pre, mid, post = s.split(CM)
commented = "\n".join(
    (line if not line.strip() or line.strip().startswith("//") else re.sub(r"^(\s*)", r"\1// ", line))
    for line in mid.split("\n")
)
s = pre + CM + commented + CM + post

pre, mid, post = s.split(AM)
uncommented = "\n".join(re.sub(r"^(\s*)// ", r"\1", line) for line in mid.split("\n"))
s = pre + AM + uncommented + AM + post

open(p, "w").write(s)
print("http-server flipped to mig-delay eval mode")
