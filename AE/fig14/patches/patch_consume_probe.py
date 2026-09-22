#!/usr/bin/env python3
"""Print what tls_consume_stream returns.

The handshake ends with the context in critical error; tlse reports the reason
as a negative return from tls_consume_stream. This captures it, with the
established state after each consume.
"""
import os, shutil, sys
p = os.path.expanduser("/homes/inho/Capybara/capybara-fig14/examples/rust/https.rs")
shutil.copy(p, p + ".pre-consume")
s = open(p).read()
old = """                    unsafe {
                        tlse::tls_consume_stream(
                            context,
                            recvbuf.as_ptr(),
                            recvbuf.len() as _,
                            None,
                        )
                    };"""
new = """                    let consume_ret = unsafe {
                        tlse::tls_consume_stream(
                            context,
                            recvbuf.as_ptr(),
                            recvbuf.len() as _,
                            None,
                        )
                    };
                    eprintln!("MIGDBG consume ret={} established={} len={}",
                        consume_ret, unsafe { tlse::tls_established(context) }, recvbuf.len());"""
if old not in s: sys.exit("anchor")
open(p, "w").write(s.replace(old, new, 1))
print("consume probe installed")
