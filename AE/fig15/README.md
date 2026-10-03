# Fig. 15 — throughput of one connection vs migration frequency

Reproduces Fig. 15 (`tput_vs_mig_freq`): a single TCP connection is migrated back and
forth between two servers at 0, 1, 10, 100, 1,000 and 10,000 migrations per second while
an open-loop client drives it at increasing load; the figure plots the peak throughput for
response sizes of 1, 8, 16, 32 and 64 KB. Paper claim (§8.2.4): migration has negligible
throughput impact for responses below 16 KB even at 1,000 migrations/s, and larger
responses still sustain ~100 migrations/s with little loss.

## Run

SSH to **node7**, then:

```bash
bash ~/capybara-AE-runs/fig15/run_fig15.sh quick   # 3 sizes x 3 frequencies, ~10 min
bash ~/capybara-AE-runs/fig15/run_fig15.sh         # 5 sizes x 6 frequencies, ~35 min (the figure)
```

The runner brings up the switch (the Fig 8 `main_eval_fig8` program with its RPS pktgen),
starts two backends on node9 per cell, sweeps the offered load of one caladan connection
from node7, records the peak achieved request rate, converts it to Gbps of HTTP response
bytes, plots the figure with the paper's own plotting code, and restores the cluster.

## Output

- `fig15_reproduction.png` / `.pdf` — the paper-layout figure (this run's data only)
- `results_fig15.txt` — one `RES` line per cell: peak rps, Gbps, migrations performed,
  the offered-load ladder that was tried
- The console prints a paper-vs-ours table (Gbps per cell).

## What to expect (AE criterion: same behavior pattern, not exact values)

(to be filled from the validation run)

## How it works

- **Backends**: the Fig 8 tree (`~/Capybara/capybara-fig8`, branch `ae-fig8`) rebuilt into
  `~/Capybara/capybara-fig15` with `--features=tcp-migration,manual-tcp-migration`. With the
  manual feature, `MIG_PER_N` is a per-connection time gate in microseconds: after a response
  is pushed, the backend initiates the connection's migration if at least `MIG_PER_N` µs have
  passed since the previous one (`examples/rust/http-server.rs`). The runner sets
  `MIG_PER_N = 1,000,000 / frequency` (0 disables migration).
- **Switch**: the Fig 8 program and setup (2 backends on node9, ports 10000/10001; the
  1 ms pktgen keeps the min-RPS migration target current, so with one connection every
  migration goes to the idle backend — a ping-pong between the two servers).
- **Client**: one open-loop caladan `synthetic` connection on node7 (`--threads=1`), 8 s per
  offered-load step; the step ladder per size brackets the paper's peak; the cell's value is
  the best achieved rate (the sweep stops once achieved throughput falls off the peak).
- **Gbps**: peak requests/s × (HTTP status line + `Content-Length` header + body) × 8.
  The paper's conversion may include a few per-packet bytes more; this matters only for the
  1 KB curve (<10%).
- The figure's 0 migrations/s point is drawn at x=0.1 (log axis), as in the paper.
