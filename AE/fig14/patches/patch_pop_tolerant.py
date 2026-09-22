#!/usr/bin/env python3
"""Let a pop on an unregistered connection create its state on demand.

In the mig-delay eval the accept arm registers no per-connection state, but the
first request can complete a pop before the migration cuts the connection over,
and the pop arm unwrapped the state map. Create the state lazily instead; the
response push on a migrating connection resolves as ETCPMIG, which the failure
arm already handles.
"""
import os, shutil, sys
p = os.path.expanduser("/homes/inho/Capybara/capybara-fig14/examples/rust/http-server.rs")
shutil.copy(p, p + ".pre-poptolerant")
s = open(p).read()
old = """                    let mut state = connstate.get_mut(&qd).unwrap().borrow_mut();"""
new = """                    let mut state = connstate
                        .entry(qd)
                        .or_insert_with(|| Rc::new(RefCell::new(ConnectionState {
                            buffer: Buffer::new(),
                            session_data: SessionData::new(session_data_size),
                        })))
                        .borrow_mut();"""
if old not in s: sys.exit("anchor")
open(p, "w").write(s.replace(old, new, 1))
print("pop made tolerant")
