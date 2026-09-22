# Fig. 8 reproduction — one command (Capybara SIGCOMM'26 AE)

Reproduces Fig. 8 (`staticl4_vs_sys_step`): step-function workload on 2 servers,
per-server workload (top row) + p99 latency (bottom row) for LWRR / Capybara-Reactive /
Capybara (proactive).

## Run

SSH to **node7**, then:

```bash
bash ~/capybara-AE-runs/fig8/run_fig8.sh     # ~10 min end-to-end
```

The script brings up the dedicated `main_eval_fig8` switch program (deterministic
client-port-parity connection binding + 2-server migration targeting + 1 ms RPS signals),
starts 2 server instances on node9 (ports 10000/10001) with a per-run dpdk-ctrl restart,
runs the 120 ms step workload (100 conns, Zipf-1.2, Server 0's load stepping
90K->270K->450K->630K->810K rps while Server 1 stays at 90K) under the three policies,
plots the 2x3 figure, and restores the cluster (switch back to port_forward baseline).

## Output

- `fig8_reproduction.png` / `.pdf` — the paper-layout figure
- Raw per-run data in `~/capybara-data/fig8*` (server RPS signal logs, request schedule,
  per-ms p99 from server-reply analysis)

## What to expect (AE criterion: same behavior pattern, not exact values)

| panel | top row (workload) | bottom row (p99, 120 ms window) |
|---|---|---|
| LWRR | Server 0 steps up & saturates (~680K), Server 1 flat | explodes to **>20 ms** once Server 0 exceeds capacity |
| Capybara-Reactive | Server 1 absorbs load in bursts after overload appears | spikes to **~1 ms** during migration waves, then recovers |
| Capybara | the two servers track each other (continuous balancing) | stays **~10–100 µs** throughout |

Repeatability observed: LWRR max ~26–27 ms; Reactive max ~1.17–1.20 ms; Capybara max
90–115 µs (defaults `MIG_THRESHOLD_PCT=60`, `MIG_CONN_RPS_CAP=200`, `MIG_COOLDOWN_MS=10`,
reactive trigger `MIG_QUEUE_TRIGGER_LEN=10`, `MCD=5`).

## How this maps to the paper's setup

Recovered from the paper's provenance snapshots (`graphs/data/test_configs/`
20240326-055550 / 20240404-090058 / 20240326-055436): same topology (2 backends,
100 conns, Zipf-1.2, step LOADSHIFTS), same three policies (no-migration /
queue-triggered reactive / threshold-based proactive with RPS_THRESHOLD~0.55-0.6).
The 2026 stack's policy knobs are exposed via env vars in `run_fig8_one.sh`
(the 2024 configs used the same semantics under older names, e.g. MAX_STAT_MIGS).

## Isolation from Fig 7 (exact-reproducibility guarantee)

Everything Fig-8-specific lives in dedicated copies; nothing used by the Fig-7
package was modified:
- server: `~/Capybara/capybara-fig8` (patches: reactive wiring re-enabled, policy
  env-parameterization, per-signal RPS logging, capylog dump on SIGINT; built with
  `tcp-migration,server-rewriting,capy-time-log,server-reply-analysis`)
- client: `~/Capybara/caladan-fig8` (built with `server-reply-analysis` — REQUIRED,
  the fig8 server embeds 16-byte metadata in replies; trace-file writing re-enabled)
- switch: `main_eval_fig8.p4` (new program; static parity SYN binding
  `src_port%2 -> backend`, PREPARE target = partner instance `origin_port^1` — the
  stock min-RPS selection picks dead register banks when only 2 of 12 backends live)
  + `sw1:~/inho/fig8/` setup & 1 ms pktgen scripts
- frozen copies + diffs: `/homes/inho/capybara-AE-runs/fig8-frozen/`

## Troubleshooting

- Bring-up is idempotent: just re-run the script.
- `SERVERS=N (want 2)`: node9 instance failed to attach; script retries the run once.
  Persistent: check `~/capybara-data/fig8*.be0` and node9 `/tmp/dc9.log`.
- All long-running pieces live in tmux (`sw`/`bft`/`swset`/`pktgen` on sw1, `f8s0/1`,
  `dc9` on node9, `iok7`/`f8c` on node7).
