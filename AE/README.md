# Capybara — SIGCOMM'26 Artifact Evaluation

Capybara is an L4 load balancer that dynamically rebalances established TCP
connections through microsecond-scale live connection migration, co-designed
between a P4 programmable switch and a kernel-bypass host stack.

This artifact reproduces the paper's main results on the authors' cluster
(the hardware — a Tofino switch and 100 GbE NICs — cannot be
virtualized). You are logged into `node7`, the orchestration host; every
experiment below is one command from this account, allocates the cluster
exclusively while it runs, and restores the cluster to a clean baseline when
it finishes (or when its deadman watchdog fires).

## Claims → experiments

| Claim (from the abstract) | Figure | Command (from `~/capybara-AE-runs/`) | Time |
|---|---|---|---|
| Up to 149× lower p99 tail latency under skew | Fig 7 | `bash fig7/run_fig7.sh quick` (or `full`) | ~18 / 45 min |
| Continuous rebalancing vs reactive/static | Fig 8 | `bash fig8/run_fig8.sh` | ~6 min |
| Works for stateful Redis (POSIX shim) | Fig 9 | `bash fig9/run_fig9.sh` | ~6 min |
| >2× throughput at 12 servers under skew | Fig 10 | `bash fig10/run_fig10.sh quick` (or `full`) | ~40 / 80 min |
| Benefits L7 LB; Prism collapses open-loop | Fig 11 | `bash fig11/run_fig11.sh` (or `full`) | ~45 / 70 min |
| Migration <3 µs CPU, <15 µs e2e; TCP+TLS | Fig 14 | `bash fig14/run_fig14.sh` | ~9 min |

**What a pass looks like** (the figure and console print these; per-figure
`figN-README` has the full expected tables and tolerances):

| Figure | Success signal on this testbed | Paper |
|---|---|---|
| Fig 7  | Capybara p99 ~10-50 us vs LWRR ~19-23 ms under Zipf → **~360-1300x** gap; short flows unharmed | up to 149x |
| Fig 8  | migrations: **Capybara 4, Reactive ~20, Static 0**; Capybara p99 stays <100 us through the step | qualitative |
| Fig 9  | Redis p99 **~0.1–0.45 ms (Capybara) vs ~10 ms (LWRR)** → **~20–120x** | ~2 orders |
| Fig 10 | Capybara peak **2.6-2.7x** the static baseline at 1/4/8 KB responses | >2x |
| Fig 11 | Capybara-L7 scales **33 -> 93 Gbps** (1->4 backends); proxy flat ~18 Gbps | linear vs flat |
| Fig 14 | zero-state migration **~10 us TCP / ~12 us TLS** end-to-end (<15 us) | <15 us |

Exact run-to-run numbers vary a few percent (client turbo drift); the gaps above
are what matters. If a cell is far off, re-run that figure once on a rested
cluster (see Pacing).

**Total time.** A full fresh reviewer dry-run of all six figures (quick paths,
with the recommended pacing breaks) takes **about 2.5 h wall-clock**
(measured end-to-end on 2026-09-22, including the automatic retries). The `full` variants of Figs 7/10/11
add roughly another hour. Suggested order: `bash check_cluster.sh` (20 s), then
**Fig 14 (~9 min)** as a smoke test, then Figs 8 and 9 (short), then the heavy ones
(7, 10, 11) with a break after every second heavy run (see Pacing below).

Run the long ones inside `tmux` (`tmux new -s ae`, later `tmux attach -t ae`) so a
dropped SSH connection cannot interrupt a run. If a run is interrupted anyway, it
cleans up after itself and can simply be started again.

Each `figN/` directory contains a short `README.md` with the
expected numbers, the paper's values, and how the runner works. Runners print
progress, write results under the same directory, and generate
`figN_reproduction.png/pdf` beside the paper's own figure for comparison.

Bonus (beyond the claimed set): `fig12/` reproduces the connection-scalability
figure (Fig. 12) up to 193K concurrent connections — all three curves
(Demikernel, Capybara-Switch, Capybara). This one is author-verified rather than
a reviewer command (it needs three server builds and the migration switch); the
reproduced figure and the numbers are in `fig12/` (`fig12_reproduction.png`,
`README.md`).

**`WALKTHROUGH.pdf`** (in this directory) records one complete pass from this
account: every command, its measured duration, the console output, and the
figure produced -- useful as a preview of what a green run looks like.

## Plot from sample data (no experiment, no cluster, ~seconds)

Every figure can be regenerated from the sample runs shipped in
`sample-data/`, without running anything on the cluster:

```
bash plot_from_samples.sh          # all six figures -> sample-figures/
bash plot_from_samples.sh 7 10     # just a subset
```

Each figure is drawn by the paper's own plotting code, using only that run's
data, so it matches the layout of the paper's figure. Use this to see what a
successful result looks like before
committing a cluster slot, or if a slot runs short. A full experiment run
overwrites the same `figN_reproduction.*` beside each figure's directory.

Plotting dependencies (pandas/numpy/matplotlib/brokenaxes) are vendored in
`pyenv-lib/` and added to the path automatically — nothing to install. See
`requirements.txt` to plot on another machine, and `ENVIRONMENT.md` for the full
hardware/software description.

## Practical notes

- `bash check_cluster.sh` (read-only, ~20 s) tells you whether the testbed is in the
  expected state before you start; WARN lines are things the runners fix themselves.
- Every runner first calls `prepare_nodes.sh`, which restores what a host reboot
  clears on the client nodes (ksched module, iokernel sysctls, hugepages, data-NIC
  link). It is idempotent; run it by hand if a runner reports `client nodes not ready`.
- Runs are exclusive: start one experiment at a time. If a session dies
  mid-run, `bash cleanup_all.sh` restores every node and the switch; a
  watchdog does the same automatically if a runner never reports back.
- The switch idles on a plain forwarding baseline between experiments;
  each runner installs the program it needs and reverts afterwards.
- Binaries and source trees live read-only under `/homes/inho/` (paths are
  already baked into the scripts); results and logs stay in your home.
- Numbers vary a few percent run to run (client-side turbo drift is the main
  source; see `fig7-README`); each README states the tolerance we observed.
- If something looks off: re-run once (transient client-core contention),
  then check the per-figure README's troubleshooting notes.

## Pacing (important)

Run figures one at a time, and after two heavy runs in a row (Figs 7, 10, 11)
give the cluster a short break: `bash cleanup_all.sh`, wait ~10 minutes, then
continue. Back-to-back heavy runs deplete client-side hugepages while
processes overlap and can zero out a run; the state fully recovers when idle.
If any cell looks far off the expected table, re-run that figure once on a
rested cluster before concluding anything.
