#!/usr/bin/env python3
"""Give the forced-migration trigger a period.

should_migrate() returns true for every receive once the counter passes
MIG_AFTER, because the counter never resets. That migrates as fast as the server
can, so each migration queues behind the last and the measured latency is
dominated by queueing rather than by the protocol.

MIG_EVERY makes the trigger periodic, which is what the microbenchmark needs:
servers busy enough to be polling, migrations far enough apart not to overlap.
The source already carried this shape as a commented-out line for a different
experiment. Default 1 keeps the previous behaviour.

Applies to the capybara-fig14 tree only.
"""
import os, shutil, sys

TREE = os.path.expanduser("/homes/inho/Capybara/capybara-fig14")
p = os.path.join(TREE, "src/rust/inetstack/protocols/tcpmig/peer.rs")
assert "capybara-fig14" in p, p

shutil.copy(p, p + ".pre-migevery")
s = open(p).read()

old = """        thread_local! {
            static COUNT: Cell<u32> = Cell::new(0);
            static MIGRATE_AFTER: OnceCell<Option<u32>> = OnceCell::new();
        }"""
new = """        thread_local! {
            static COUNT: Cell<u32> = Cell::new(0);
            static MIGRATE_AFTER: OnceCell<Option<u32>> = OnceCell::new();
            static MIGRATE_EVERY: OnceCell<u32> = OnceCell::new();
        }"""
if old not in s:
    sys.exit("ANCHOR 1 not found")
s = s.replace(old, new, 1)

old2 = """        let count = COUNT.get();
        COUNT.set(count + 1);
        // eprintln!("count: {}", count);
        count >= migrate_after"""
new2 = """        let every = MIGRATE_EVERY.with(|e| {
            *e.get_or_init(|| {
                std::env::var("MIG_EVERY")
                    .ok()
                    .and_then(|n| n.parse().ok())
                    .filter(|n| *n > 0)
                    .unwrap_or(1)
            })
        });
        let count = COUNT.get();
        COUNT.set(count + 1);
        count >= migrate_after && count % every == 0"""
if old2 not in s:
    sys.exit("ANCHOR 2 not found")
s = s.replace(old2, new2, 1)

open(p, "w").write(s)
print("MIG_EVERY added to", p)
