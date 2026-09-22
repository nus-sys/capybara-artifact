#!/usr/bin/env python3
"""Take the slow path out of the migration critical section.

When fast migration has not yet been enabled for a connection, the PREPARE_ACK
handler flushes the TCP queue and migrates out inline. That flush sits between
RECV_PREPARE_MIG_ACK and SEND_STATE, which is exactly the interval the figure
attributes to origin CPU, and it is why that interval measures tens to hundreds
of microseconds here against the paper's sub-microsecond.

The source marks the region for removal when measuring migration delay. The fast
path in tcp/peer.rs already runs unconditionally, so the connection still
migrates; only the inline flush goes away.

Applies to the capybara-fig14 tree only.
"""
import os, re, shutil, sys

TREE = os.path.expanduser("/homes/inho/Capybara/capybara-fig14")
p = os.path.join(TREE, "src/rust/inetstack/mod.rs")
assert "capybara-fig14" in p, p

shutil.copy(p, p + ".pre-migdelay")
s = open(p).read()

MARK = "/* COMMENT OUT THIS FOR MIG_DELAY EVAL */"
parts = s.split(MARK)
if len(parts) != 3:
    sys.exit(f"expected two markers, found {len(parts) - 1}")

body = parts[1]
if "is_fast_migrate_enabled" not in body:
    sys.exit("region between markers is not the slow path")
if body.strip().startswith("//"):
    sys.exit("region already commented out")

commented = "\n".join(
    (line if not line.strip() else re.sub(r"^(\s*)", r"\1// ", line))
    for line in body.split("\n")
)

s = parts[0] + MARK + commented + MARK + parts[2]
open(p, "w").write(s)
print("slow path disabled in", p)
