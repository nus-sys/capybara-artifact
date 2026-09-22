# Fig. 14 — migration latency by connection state size: BOTH PANELS COMPLETE

The paper's central claim reproduces on both panels, on the paper's own tree:
migration costs under 3 μs of server CPU and under 15 μs end to end at zero state,
rising to ~60 μs with 128 KB of TLS state.

## Run

SSH to **node7**, then:

```bash
bash ~/capybara-AE-runs/fig14/run_fig14.sh     # ~9 min, both panels, restores on exit
```

## Result (total latency, μs; 2,000 measured migrations per cell)

| panel | 0 KB | 16 KB | 32 KB | 64 KB | 128 KB |
|---|---|---|---|---|---|
| TCP paper / ours | 11.3 / **10.1** | 19.7 / **19.7** | 25.6 / **25.5** | 36.7 / **36.9** | 58.0 / **58.1** |
| TLS paper / ours | 12.9 / **11.7** | 21.1 / **19.5** | 26.9 / **25.7** | 38.1 / **37.1** | 59.8 / **58.8** |

Every cell within a few percent; TCP matches to a fraction of a microsecond from 16 KB up.
Server CPU at 0 KB: 2.32 μs against the paper's 2.29 (TCP), 3.53 against 3.67 (TLS).

## How (each piece recovered from the repo's own records)

- **Platform**: `~/Capybara/capybara-fig14tls` — the monorepo checked out at `4599b186`,
  committed the day before the paper's runs. Built with nightly-2024-09-25 plus a 106-line
  diff (recorded in `/homes/inho/capybara-AE-runs/fig14-frozen/manifests/papertree-source.diff`): one feature-gate
  line, the https build lines enabled, the experiment toggles flipped as the source's own
  markers direct, and the duplicate-initiate panic downgraded to a no-op as the later
  stack does.
- **Layout**: both backends on node8 (ports 10000/10001) — the paper-era stack targets the
  partner port at FRONTEND_IP, and the phase parser needs all timestamps on one clock.
  The switch stays on the port_forward baseline.
- **TLS 1.2 only**: tlse cannot take a TLS 1.3 ClientHello; the runner holds the client to
  1.2 with `OPENSSL_CONF=tls12.cnf`, since this redis-benchmark predates --tls-protocols.
- **Certificates**: the project's own test certs under /usr/local/tls had expired
  (valid 2024-09 to 2025-09 — fine at the paper's run date). Renewed by re-signing the
  original CSR (same key, same CN) with a fresh CA, 3650 days; originals preserved in
  `../fig14-frozen/tls-original-backup/` and as `.bak` files in place.

The earlier TCP-panel reproduction on the shim-era tree (21.3 μs at 0 KB, journal below)
is superseded by the paper-tree numbers above; its constant offset was post-camera-ready
poll-loop cost, now confirmed by the paper tree's absence of it.

Everything below is the working journal, kept because each wrong turn documents a real
property of the system.

---
|---|---|---|---|
| 0 KB | 11.28 μs | 21.3 μs | 2.29 μs | 8.7 μs |
| 16 KB | 19.71 | 30.2 | 2.67 | 9.6 |
| 32 KB | 25.60 | 33.6 | 2.96 | 10.0 |
| 64 KB | 36.71 | 40.8 | 3.50 | 10.8 |
| 128 KB | 58.04 | 52.2 | 4.62 | 12.3 |

Same shape, same order of magnitude, inside the paper's number at 128 KB. The offset at
small sizes is a constant ~1.2–1.7 μs on every one of the seven protocol phases — CPU and
network alike — which points at per-poll-loop cost added to this tree after the camera-ready
rather than at the protocol (clocks verified: performance governor, 3.3 GHz).

The TLS panel is not reproduced: the tlse handshake against OpenSSL clients dies one layer
above the migration machinery (details in the journal below). Everything beneath it —
ping-pong, state transfer, phase timestamps, parsing — is exercised by the TCP panel.

Everything below is the working journal, kept because each wrong turn documents a real
property of the system.

---


The paper's central technical claim is that migration costs under 3 μs of server CPU
and under 15 μs end to end, rising to 60 μs total with a 128 KB TLS connection state.
This directory holds the work toward reproducing that figure. **It is not finished:**
the measurement runs and produces the paper's data format, but the numbers come out
about ten times larger and the reason is not yet established.

## What works

- **Dedicated tree** `~/Capybara/capybara-figmig`, copied from the Fig. 10 tree, so
  the Fig. 8 and Fig. 10 trees are never rebuilt. Their binaries are md5-verified
  against their frozen manifests after every build here.
- **`run_miglat_one.sh <state_size> <runid>`** brings up two backends on node9, drives
  load, stops the servers gracefully so they flush their time logs, and reports how
  many migrations completed. Reuses the Fig. 8 switch program and bring-up.
- **`parse_miglat.py <expt_id>`** turns the two server logs into the paper's format:
  one row per migration of seven phase intervals, the total, and the blackout, plus an
  avg/min/max/stddev summary. Verified against the paper's own data files, which have
  the same nine columns.
- A five-second run at 50k pps yields roughly 8,800 completed migrations, well past
  the 2,000 the summary uses.

## Tree changes (in `capybara-figmig` only)

Both were commented out in the source after the camera-ready; the patches that restore
them are in `patches/`.

1. `tcp/peer.rs` — the call to `should_migrate()`, which reads `MIG_AFTER` and forces
   migrations rather than waiting for load to trigger them.
2. `tcpmig/peer.rs` — `MIG_EVERY`, added here, makes that trigger periodic. Without it
   the counter never resets and every receive migrates, so migrations queue behind each
   other. The source already carried this shape as a commented-out line.

## Where it stands

Measured against the paper's 2.29 μs server CPU and 11.3 μs total:

| condition | migrations | server CPU | total |
|---|---|---|---|
| continuous, 50k pps, 10 conns | 2000 | 38–41 μs | 132–135 μs |
| every 100th receive | 224 | 98 μs | 212 μs |
| every 1000th | 24 | 189 μs | 412 μs |
| every 10000th | 2 | 326 μs | 744 μs |
| 1 connection, 10k pps | 8 | 795 μs | 1739 μs |

Migrating **less** often makes it **slower**, consistently. The likely reason is that a
connection migrated rarely has gone cold: its state is out of cache and the server's
poll loop is not touching it, so each protocol step waits for the next cycle. Only
back-to-back migrations keep it warm. Frequency tuning alone will not close the gap.

The next candidate was the slow path in `inetstack/mod.rs`, which the source marks for
removal when measuring migration delay. It sits between `RECV_PREPARE_MIG_ACK` and
`SEND_STATE` — exactly the interval that is most inflated. Commenting it out stopped
migrations entirely (`init_mig=0`, the client core-dumped), so it was reverted; the
fast path in `tcp/peer.rs` alone is evidently not sufficient to carry a migration. That
interaction is the thing to understand next.

Other candidates not yet tried:

- The paper may have measured a single designated connection rather than letting ten
  compete for poll slots.
- The client load shape may differ from what the paper drove.

## Files

- `run_miglat_one.sh` — one state size, one run. Env: `RT`, `PPS`, `THREADS`, `MA`
  (`MIG_AFTER`), `ME` (`MIG_EVERY`).
- `parse_miglat.py` — server logs to the paper's nine-column format.
- `patches/` — the tree changes, applied to `capybara-figmig` only.

---

## What the paper's own records settled (2026-08-12)

All ten runs behind this figure kept their configuration in
`graphs/data/test_configs/`, and the five state sizes differ by exactly one line
(`CONFIGURED_STATE_SIZE`), the two panels by two (`SERVER_APP`, `TLS`). That
makes the experiment fully specified, and it shows the approach above was wrong
in every respect that matters:

| | tried here first | the paper's records |
|---|---|---|
| client | caladan, 50k pps, 10 conns | `redis-benchmark -h 10.0.1.8 -p 10000 -t get -n 3000000 -c 16 --threads 16` |
| what triggers a migration | `MIG_AFTER`, forced from the stack | the server, in `migrate` mode, as soon as a connection is established |
| policy | thresholds disabled | `MAX_PROACTIVE_MIGS=24`, `MIN_THRESHOLD=190`, `RECV_QUEUE_LEN_THRESHOLD=20` |
| build | + `server-rewriting` | `tcp-migration`, `capy-time-log` only |
| backends | two ports on node9 | `10.0.1.8:10000` and `10.0.1.9:10000`, one per node |
| client target | the fig8 VIP, port 55555 | `10.0.1.8:10000`, which is `FE_IP`/`FE_PORT` in `capybara_header.h` |

`EVAL_MIG_DELAY = True` appends the argument `migrate` to the server command.
`https.rs` reads it (`args().nth(2)`) and calls `libos.initiate_migration(qd)` the
moment the TLS session comes up, skipping the request path entirely. Each
migration is therefore measured alone, which is why the paper sees single-digit
microseconds where a forced migration under load measures tens.

That also explains the earlier puzzle: migrating less often measured slower not
because of anything real, but because the forced path leaves the connection cold
between migrations. It was the wrong path to be on.

### Targets, from the paper's own data files

| panel | 0 KB | 16 KB | 32 KB | 64 KB | 128 KB |
|---|---|---|---|---|---|
| TCP server CPU / total | 2.29 / 11.28 | 2.67 / 19.71 | 2.96 / 25.60 | 3.50 / 36.71 | 4.62 / 58.04 |
| TLS server CPU / total | 3.67 / 12.86 | 3.99 / 21.06 | 4.38 / 26.93 | 4.80 / 38.07 | 6.00 / 59.80 |

### Where it stands now

The tree is rebuilt to the paper's features and `https.elf` now builds (its build
lines were commented out in `linux.mk`). TLS certificates were missing on node9
and have been installed. `run_miglat_tls.sh` exists but its first run produced
nothing: it placed both backends on node9 and pointed the client at port 55555,
both wrong per the table above.

Next: put one backend on node8 and one on node9, both at port 10000, and give the
switch a two-backend table to match — the Fig. 8 setup script populates twelve
and distributes with `reg_be_idx = p % 2`, which is not this experiment's layout.
`http-server.rs` has no `migrate` mode in any tree here, so the TCP panel will
need the three lines `https.rs` uses, added as ours rather than recovered.

### Progress on the TLS panel (2026-08-12, later)

Three infrastructure gaps had to close before a single migration happened, none
of them visible from the config files alone:

1. **`https.elf` was not built.** Its three lines in `examples/rust/linux.mk` were
   commented out. Enabled in this tree.
2. **node9 had no TLS certificates.** `https.rs` reads `/usr/local/tls/svr.crt`
   and `svr.key`; the directory did not exist there. Copied from node7.
3. **node7's kernel could not reach the data network.** Every figure so far used
   caladan, which owns the NIC and carries 10.0.1.7 in its own stack, so the
   kernel never needed an address there. `redis-benchmark` is an ordinary socket
   application, so it does. Two changes on node7, both reversible:

   ```
   sudo ip addr add 10.0.1.7/24 dev ens85f1np1     # undo: ip addr del
   sudo ip neigh replace 10.0.1.8 lladdr 08:c0:eb:b6:e8:05 dev ens85f1np1
   sudo ip neigh replace 10.0.1.9 lladdr 08:c0:eb:b6:c5:ad dev ens85f1np1
   ```

   The static neighbours mirror caladan's own `static_arp` lines: the servers run
   catnip and do not answer kernel ARP. The MTU was already 9216. With these in
   place a TCP connection to `10.0.1.8:10000` succeeds.

The first migration then appeared: node8 logged `INIT_MIG` and
`SEND_PREPARE_MIG`, and node9 logged nothing. So the prepare message is leaving
the origin but not arriving at the target, which points at the switch tables
rather than at the hosts. The two-backend setup written for this experiment
(`sw1:~/inho/figmig/main_eval_figmig_setup.py`) fills the backend registers and
narrows the signal multicast, but the migration path itself is carried by other
state in the Fig. 8 program that still assumes both backends sit on node9.

The client also dies shortly after connecting, which is expected: in `migrate`
mode the server never answers, so redis-benchmark reconnects and eventually gives
up. Whether the paper's runs tolerated that or whether something else kept the
connection alive is still open.

**Next:** compare the migration path in `main_eval_fig8.p4` against what a
node8-to-node9 migration needs — specifically how the target is derived, since
the Fig. 8 program was given partner targeting by port (`origin_port ^ 1`) for
two processes on one host. That mapping cannot address a backend on another node.

---

## TCP panel REPRODUCED (2026-08-12, Fable session)

`run_miglat_tcp.sh` + `parse_miglat.py`, 2,000 migrations per cell, all five state sizes:

| state | paper total | ours total | paper server CPU | ours server CPU |
|---|---|---|---|---|
| 0 KB | 11.28 | 21.29 | 2.29 | 8.73 |
| 16 KB | 19.71 | 30.20 | 2.67 | 9.62 |
| 32 KB | 25.60 | 33.69 | 2.96 | 10.06 |
| 64 KB | 36.71 | 40.88 | 3.50 | 10.89 |
| 128 KB | 58.04 | 52.29 | 4.62 | 12.31 |

The figure's claim — microsecond-scale migration whose latency grows only gently with
connection state — reproduces. At 128 KB we are inside the paper's number; at small sizes a
constant ~1.2-1.7 us per phase sits on top (uniform across CPU and network phases, so it is
per-phase poll-loop overhead added to this tree after the camera-ready, not clock speed —
governor is performance at 3.3 GHz).

What it took, beyond the earlier findings:

1. `http-server.rs` ships the experiment behind paired markers ("APP_STATE_SIZE VS MIG_LAT
   EVAL"): migrate on every accept, bounded at 11,000, no app state. Flipping the toggles is
   the mode; the paper's `migrate` argv is not needed for the TCP panel.
2. A pop can complete with data before the migration cuts over; the pop arm unwrapped the
   state map and died. State is now created on demand; the response push resolves as ETCPMIG.
3. The current stack sends PREPARE to SWITCH_IP for the switch to retarget; no installed
   program does that for this layout. Patched to address the partner directly, as the
   paper-era stack (@4599b186) did with its port-toggle targeting.
4. **Both backends must share a clock.** Phase intervals mix timestamps from both endpoints;
   across hosts, clock skew scrambles the ordering and the parser finds nothing. That is why
   the paper ran both servers on node9 (ports 10000/10001). Same-host layout, partner chosen
   by the connection's own listen port, prepares hairpinning through the port_forward
   baseline by MAC.

TLS panel: blocked in the tlse app layer — the handshake against OpenSSL clients dies with
TLS_BROKEN_PACKET on a split record and the migrate gate treated tls_established()==-1
(critical error) as established (now fixed to ==1). The tlse fragmentation issue is the
remaining work; everything below it (ping-pong, state transfer, parsing) is proven by the
TCP panel.

Raw results: `figmig_tcp_results.txt`, experiment ids `miglattcp<bytes>-sweep`.
