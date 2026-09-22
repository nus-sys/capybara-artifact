# Fig. 7 reproduction — one command (Capybara SIGCOMM'26 AE)

Reproduces Fig. 7 (main_eval p99: LWRR vs Capybara across Uniform / Zipf-0.9 / 1.0 / 1.2,
all-flows + short-flows panels) on the authors' testbed.

## Run

SSH to **node7** (see cluster access notes provided by the authors), then:

```bash
bash ~/capybara-AE-runs/fig7/run_fig7.sh quick   # 3 runs/cell, ~20 min  (sanity check)
bash ~/capybara-AE-runs/fig7/run_fig7.sh         # 10 runs/cell, ~60 min (full protocol)
```

The script handles the whole run: brings up the Tofino switch (main_eval P4 program, ports,
tables, pktgen), starts iokerneld on the client nodes, runs a pilot to validate the
datapath, sweeps both systems over all four workloads, plots the figure, and restores
the cluster (switch back to the port_forward baseline) when it exits — including on Ctrl-C.

## Output

- `fig7_reproduction.png` / `.pdf` — the paper-layout figure (copy it out with
  `scp node7:capybara-AE-runs/fig7/fig7_reproduction.png .`)
- `fig7_results.txt` — one line per run (raw data, written by your run)
- `fig7_results.authors-reference.txt` — the authors' dataset behind the published figure
- A summary table is printed at the end.

## What to expect (AE criterion: same overall trend, not exact values)

All-flows p99, median of repeats:

| | Uniform | Zipf-0.9 | Zipf-1.0 | Zipf-1.2 |
|---|---|---|---|---|
| LWRR | ~15–30 µs | **>1000 µs** (bimodal: some runs stay ~15–40 µs) | **>1000 µs** | **>1000 µs** |
| Capybara | ~15 µs | ~15–25 µs | ~15–50 µs | **~25–130 µs** |

The paper's claim to check: **Capybara keeps ~100 µs-scale tail latency across all skews,
while LWRR blows up by orders of magnitude under skew.** Individual runs are bimodal at the
boundary skews (LWRR@0.9, Capybara@1.2); the per-run dots on the figure show this honestly.
LWRR runs at 1.8M pps and Capybara at 1.35M pps — each at its calibrated operating point on
this cluster (the current client NICs/nodes have a lower per-connection ceiling than the
original paper testbed; see the AE appendix note).

## Interruptions / re-runs

Every invocation measures from scratch. If a `fig7_results.txt` is already present it is
archived to `fig7_results.<timestamp>.prev.txt` before the sweep starts, so a reviewer's run
can never be satisfied by someone else's data.

If a run is interrupted (a dropped SSH session, say), pass `resume` as a second argument to
pick up where it stopped instead of re-measuring the completed cells:

```bash
bash ~/capybara-AE-runs/fig7/run_fig7.sh full resume
```

Reused cells are named in the log. The authors' own dataset is kept separately as
`fig7_results.authors-reference.txt` and is never read by the sweep.

## Troubleshooting

- **Pilot fails twice**: usually the switch table config (bfshell is flaky). Re-run the
  script once more; it re-applies the config. Logs: `sw1:/tmp/{switchd,bft,swset,pktgen}.log`.
- **`FLEET=N (want 12)`**: a server instance failed to attach; the script retries the run
  automatically. Persistent failures: check `/tmp/hs8_0.log` (etc.) on node8/9/10.
- Everything the sweep starts runs inside tmux sessions (`sw`/`bft`/`swset`/`pktgen` on sw1,
  `hs0..3`/`dc8..10` on servers, `iok*`/`cl*`/`sf*` on clients) — attach to inspect live.

## Frozen state (exact reproducibility)

`/homes/inho/capybara-AE-runs/fig7-frozen/` snapshots everything this figure was produced with:
git commit points + full diffs of the three code trees (`manifests/`), the exact binaries
(`bin/`, md5-summed), client/server configs (`configs/`), and the switch P4 sources +
compiled artifacts (`switch/sw1-fig7-frozen.tgz`). Later code changes cannot break this
figure: restore by checking out the recorded HEAD, applying the diff, and/or copying the
frozen binaries back to the paths recorded in the manifests.
