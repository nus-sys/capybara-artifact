# Fig. 10 reproduction — one command (Capybara SIGCOMM'26 AE)

Reproduces Fig. 10 (`large_scale`): peak throughput with 12 servers and 720 long-lived
connections under a Zipf-1.2 skew (LWRR / Capybara) against the uniformly-balanced ideal,
for 1 / 4 / 8 / 16 / 20 KB responses.

## Run

SSH to **node7**, then:

```bash
bash ~/capybara-AE-runs/fig10/run_fig10.sh quick    # ~45 min
bash ~/capybara-AE-runs/fig10/run_fig10.sh          # full ladders, ~80 min
```

For each condition x size the sweep climbs a load ladder and stops at the first rung whose
p99 exceeds 1 ms; the peak is the highest sustained rung. A violated rung is retried once
before the ladder is abandoned, because Capybara at large response sizes is bimodal — an
unlucky run hits a migration storm at a load the next run sustains. A deadman watchdog
(auto-cleanup after 2.5 h) is armed for the whole run.

## What to expect (AE criterion: same behavior pattern, not exact values)

Peak throughput, three client nodes, jumbo frames (the paper's configuration):

| response size | 1 KB | 4 KB | 8 KB | 16 KB | 20 KB |
|---|---|---|---|---|---|
| LWRR (ours) | **31%** | **32%** | **34%** | **45%** | **40%** |
| LWRR (paper) | 40% | 35% | 41% | 47% | 50% |
| **Capybara (ours)** | **84%** | **90%** | **83%** | **85%** | **65%** |
| Capybara (paper) | 76% | 74% | 82% | 84% | 89% |
| Uniform ideal, ours (paper) | 52.4 G (55.1) | 160.2 G (181.1) | 228.8 G (246.6) | 171.3 G (229.5) | 163.4 G (216.5) |

The qualitative result reproduces at every size: a static L4 balancer keeps only a third to
a half of the uniformly-balanced ideal under skew, while Capybara recovers most of it. Our
LWRR runs a few points below the paper's and our Capybara a few points above at the small
sizes; 20 KB is the one cell that falls short (65% vs 89%, see below).

Absolute Gbps land within 5-13% of the paper at 1-8 KB. At 16 / 20 KB our ideal is lower
(171 / 163 G vs 229 / 217 G) because saturating twelve backends at those sizes needs more
offered load than three client nodes can generate.

**If a size shows `SKIP ... node5/6 completed 0` in the log, or `NO DATA - client node
limited` in the figure summary:** one of the two weaker client nodes (node5/6) failed to
drive that size — a transient of a heavily-used cluster, not a Capybara result. The runner
omits that size (the plot shows a gap, never a misleading low bar). Re-run it on a rested
cluster (the whole figure with `bash fig10/run_fig10.sh quick`, or just the affected size
with e.g. `SIZES='8192' bash fig10/run_fig10.sh quick`) and it reproduces.

## Peak criterion

Peak = the highest offered load whose p99 is still sane (<= 1 ms). This is how the paper's
own spreadsheets (`graphs/data/*.xlsx`, sheets "large scale …" and "SOSP 25") picked their
operating points: rows with a latency blow-up were discarded, rows the client could not
fully drive were kept. Scoring on achieved-vs-offered instead inflates LWRR to ~95% of the
ideal, because under overload the raw completion count keeps rising while latency explodes.

## Methodology notes (why these knobs)

- **Segmentation: `MSS=8960`, not 9000.** A full 9000-byte segment plus the 40-byte IP/TCP
  header is 9040 bytes, past the 9000-byte path MTU, so every response that spans more than
  one segment paid an extra round of fragmentation. Responses of 1-8 KB fit in a single
  segment and are unaffected (8 KB measures 209.2 vs 209.2 Gbps either way), but 16 KB goes
  from 91% to 100% of offered load at 1.2 M rps with p99 dropping 158 -> 132 us. This is
  what unblocked the 16 / 20 KB columns. The paper-era driver (`eval/test_config.py`) shipped
  `MTU=9000 MSS=9000` with a comment noting the smaller value was needed; the runner now
  defaults to `MTU=9000 MSS=8960` and both are overridable via `SMTU` / `SMSS`.
- **Zipf-1.2 skew applies to the 720 connections, not to the 12 server groups.** Skewing the
  groups directly makes the hottest server take 38.8% of the load instead of 27.4%, which
  sinks LWRR well below the paper. `gen_spec.py conn_zipf` builds the correct spec.
- **Client kthreads: 24.** At the 12-18 the configs originally carried, the clients — not
  the servers — capped every condition (8 KB aggregate 144 -> 238 Gbps at 24).
- **Back pressure, not panic.** `http-server` used to treat `EBUSY` from `Sender::send()` as
  fatal, so overload *killed* backends (7 of 12 in one 16 KB run); multi-segment responses
  fill the unsent queue two to three times faster. It is now handled as back pressure and
  `UNSENT_QUEUE_CUTOFF` is raised to 64 KB. 16 KB went from 89 to 231 Gbps.
- **Jumbo frames end-to-end**: server `USE_JUMBO=1`, dpdk-ctrl `MTU=9216`, switch ports
  `TX/RX_MTU=9400`, client `iokerneld` rebuilt with `IOKERNEL_MTU=9216` + 9600-byte mbufs
  and `INGRESS_MBUF_SHM_SIZE` raised to 2 GB so the original mbuf count still fits —
  reducing the count instead makes the client hit `ENOBUFS` and punch holes in its own
  request stream. Kernel netdev MTUs on all data NICs set to 9216.
- **Uniform is an upper bound.** It is the same 720 connections and the same offered load
  spread evenly over the 12 backends, so no policy can beat it; a cell measuring above 100%
  means the harness, not the servers, was the binding constraint there.
- **20 KB Capybara (65% vs the paper's 89%).** Above ~650 k rps this cell is reproducibly
  bimodal: p99 either stays at ~35 us or jumps past 20 ms, and the failures recur across
  retries and across migration-aggressiveness settings (`MIG_CONN_RPS_CAP` 30 and 50). At
  20 KB a response spans three segments, so a migration blackout costs proportionally more
  in-flight data than at any smaller size. Reported as measured.

## fig10-only changes (dedicated `capybara-fig10` tree + new switch program)

1. Switch `main_eval_fig10.p4`: static client-port binding (`reg_be_idx[p]=p%12`, no RR
   increment) so each client connection lands deterministically on the server group its
   workload spec targets; original min-RPS migration targeting retained (all 12 backends
   live). Setup: `sw1:~/inho/fig10/main_eval_fig10_setup.py`.
2. Server tree patches: immediate-path MSS clamp + full-drain loop and the raised unsent
   cutoff (`tcp/established/sender.rs`), `EBUSY` back pressure in `http-server.rs`, larger
   catnip mbuf pools. Build features: `tcp-migration,server-rewriting,capy-time-log`
   (NO `server-reply-analysis` — it ignores `DATA_SIZE` and overwrites response bytes).
3. Client: `target-fig10` build + `client_node{5,6,7}_f10.config` (jumbo, 24 kthreads).
4. Throughput measured from client-side completion histograms (`/tmp/f10x.latency`);
   p99 read from the synthetic client's own summary line.

## Files

- `run_fig10.sh` — the one command above.
- `fig10_sweep_final.sh` — ladders + p99 peak criterion + single retry.
- `run_fig10_one.sh` — a single (condition, size, load) point. Env: `SMTU`, `SMSS`, `RT`,
  `THREADS`, `CAP`, `FLOOR`, `DIST_OVERRIDE`.
- `plot_fig10_final.py` — figure; paper reference values are inlined from
  `graphs/data/large_scale.csv`.
- `fig10_results_mss8960.txt` — every measurement behind the published figure.
- `percore_cap.sh` — single-server capacity ladder, the same measurement as the paper's
  "SOSP 25" spreadsheet sheet; confirms our per-server capacity matches or beats the
  paper-era numbers, so nothing regressed in the stack.
- `/homes/inho/capybara-AE-runs/fig10-frozen/` — binaries (md5-manifested), switch state, git manifests, scripts.

## Safety kit (applies to all figures)

- `~/capybara-AE-runs/cleanup_all.sh` — one-command full cluster cleanup + switch baseline
  restore. Safe anytime.
- `~/capybara-AE-runs/arm_watchdog.sh [ttl]` — deadman timer; if an orchestrator dies
  (e.g. dropped connection), the cluster is auto-cleaned when the TTL expires.
- Per-run processes are wrapped in `timeout` (dpdk-ctrl 20 min, servers 15 min, clients
  5 min) so nothing outlives a crashed run.
