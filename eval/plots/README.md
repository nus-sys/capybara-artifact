# Figure regeneration from sample data

This directory regenerates the paper's evaluation figures from the measurement
data used in the camera-ready (`data/`), without running any experiment.

## Setup

```
pip install -r requirements.txt
```

Tested with Python 3.9 (matplotlib 3.8.2, pandas 2.1.3, numpy 1.26.2) and with
the paper's build environment (Python 3.13, matplotlib 3.9.2, pandas 2.2.3).

## Usage

```
python3 create_plots.py <figure> [<figure> ...]
```

Output PDFs are written next to the script. The script is path-independent
(it can be invoked from any working directory).

## Verified figures (main body)

All 14 regenerate cleanly from `data/`:

| Command argument | Paper figure |
|---|---|
| `motivation` | Fig. 2 — motivating tail-latency experiment |
| `main_eval_p99` | Fig. 7 — p99 latency, LWRR vs Capybara, all/short flows |
| `staticl4_vs_sys_step` | Fig. 8 — step workload, LWRR / Reactive / Proactive |
| `redis_latency_cdf` | Fig. 9 — Redis tail-latency CDF, LWRR vs Capybara |
| `redis_maintenance` | Fig. 18 — throughput during server maintenance |
| `large_scale` | Fig. 10 — large-scale throughput vs LWRR / Uniform |
| `main_eval_http_latency_cdf` | HTTP tail-latency CDF |
| `four_servers_latency_cdf` | 4-server latency CDF (LWRR / RR / load-aware) |
| `server_scalability_l7` | scaling vs #servers (L7) |
| `server_scalability_l4` | Fig. 13 — scaling with server count, Capybara vs Capybara-SW |
| `connection_scalability` | Fig. 12 — connection scalability |
| `state_size_vs_mig_latency` | Fig. 14 — migration latency vs connection state size |
| `tput_vs_mig_freq` | Fig. 15 — throughput vs migration frequency |
| `blocking_vs_non_blocking` | Fig. 16 — buffered (non-blocking) migration |

Running with no arguments attempts every `plot_*` function in the script,
including legacy/exploratory ones; prefer the named figures above.

## Data provenance

- `data/` is a verbatim copy of the paper repository's `graphs/data/`: the
  exact CSVs / parsed traces behind the camera-ready figures.
- `data/test_configs/` holds per-run `test_config.py` snapshots (keyed by
  experiment ID) recording the full configuration of individual runs, e.g.
  the three runs of Fig. 8 (`20240326-055550` LWRR, `20240326-055436`
  proactive, `20240404-090058` reactive) and the `four_servers_latency_cdf`
  runs (`20240410-143658` LWRR, `20240410-143027` round-robin,
  `20240410-140807` load-aware).
