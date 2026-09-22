# Fig. 9 reproduction — one command (Capybara SIGCOMM'26 AE)

Reproduces Fig. 9 (`redis_latency_cdf`): top-10% tail-latency CDF of two Redis servers
(running unmodified on Capybara via the POSIX shim layer) under a seeded 5-second
shifting workload (~60% average utilization, Zipf-1.2 across 100 long-lived connections),
LWRR vs Capybara.

## Run

SSH to **node7**, then:

```bash
bash ~/capybara-AE-runs/fig9/run_fig9.sh     # ~6 min end-to-end
```

## Output

- `fig9_reproduction.png` / `.pdf` — CDF (y in [0.9, 1.005], x log-scale), with the
  paper's original curves overlaid as dotted references.

## What to expect (AE criterion: same behavior pattern, not exact values)

| | p99 | shape |
|---|---|---|
| LWRR | **~10–15 ms** | tracks the paper's LWRR curve closely |
| Capybara | **~120–450 µs** | same shape as the paper's curve (paper p99 ≈ 108 µs) |

Ratio 20–120× across runs (paper: 74×). The workload spec is REGENERATED from the paper's
seeded generator (`gen/loadshift_spec.txt`, seed 2402271237 + the 2024 config parameters
recovered from the experiment history) — byte-identical to the paper runs' offered load.

## Setup notes

- 2 Redis instances on node9 (ports 10000/10001) run the stock `capybara-redis` binary
  under `LD_PRELOAD=libshim.so` from the dedicated `capybara-fig9` tree; both load the
  same historical AOF at startup. Client is the caladan fork (`--protocol=resp`,
  `REDIS_PRELOAD=0` for symmetric GETs).
- Client targets VIP `10.0.1.8:55555` (the stack's server-rewriting origin constant).
- Capybara policy (via env in `run_fig9_one.sh`): signal-driven shedding with
  `FAIR_SHARE_N=2 MIG_THRESHOLD_PCT=65 MIG_CONN_RPS_CAP=30 MIG_COOLDOWN_MS=10` —
  i.e. rebalance early and move only small connections (the 2024 proactive semantics).
- Uses the same `main_eval_fig8` switch program as Fig 8 (parity binding + partner
  migration targeting).

## fig9-tree patches (dedicated `capybara-fig9` copy; nothing shared with Fig 7/8 changed)

1. `shim/src/interpose.c`: constructor-phase guard — interposed calls pass through to
   libc until all shared-library constructors have run (otherwise the mlx5 PMD's sysfs
   reads triggered demikernel/EAL init before the PMD registered -> "No ethernet ports").
2. `src/rust/catnip/mod.rs` + `src/rust/inetstack/mod.rs`: the stock "Redis eval mode"
   toggles (guard panic removed; `poll_bg_work` commented in `wait2`, per the in-code
   markers).
3. `tcp/peer.rs`: optional `MIG_ONLY_IDLE` gate (off by default).
Client (`caladan-fig8` tree, `target-noreply` build without server-reply-analysis):
`REDIS_PRELOAD=0` skip knob + per-key preload log spam removed (resp.rs).

## Troubleshooting

- LWRR runs occasionally leave wedged connections; the runner waits for the client to
  exit and for the trace file to stabilize, and the orchestrator retries a failed run.
- All long-running pieces are in tmux (`f9s0/1`, `dc9` on node9, `iok7`/`f9c` on node7).
