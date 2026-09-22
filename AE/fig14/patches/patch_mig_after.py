#!/usr/bin/env python3
"""Re-enable the forced-migration trigger for the migration-latency figure.

should_migrate() reads MIG_AFTER and fires every N receives, which is how the
paper drove thousands of migrations through one connection. Its call site was
commented out after the camera-ready, leaving the knob inert. This restores it in
the capybara-fig14 tree only; capybara-fig8 and capybara-fig10 are untouched.
"""
import os, shutil, sys

TREE = os.path.expanduser("/homes/inho/Capybara/capybara-fig14")
p = os.path.join(TREE, "src/rust/inetstack/protocols/tcp/peer.rs")

# refuse to run against any tree but the dedicated one
assert "capybara-fig14" in p, p

shutil.copy(p, p + ".pre-fig14")
s = open(p).read()

old = """            // #[cfg(feature = "tcp-migration")]
            // if self.tcpmig.should_migrate() {
            //     self.initiate_migration_by_addr((local, remote));
            // }
"""
new = """            #[cfg(feature = "tcp-migration")]
            if self.tcpmig.should_migrate() {
                self.initiate_migration_by_addr((local, remote));
            }
"""
if old not in s:
    print("ANCHOR NOT FOUND - nothing changed", file=sys.stderr)
    sys.exit(1)

open(p, "w").write(s.replace(old, new, 1))
print("restored should_migrate() call site in", p)
