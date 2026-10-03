# Fig. 13 — peak throughput vs number of servers: Capybara vs Capybara-SW

Reproduces Fig. 13 (`server_scalability_l4`): peak request rate with 1, 2, 4, 8 and 12
servers, for Capybara on the Tofino switch and for Capybara-SW, the same load balancer
implemented as a DPDK software switch on an end host (one core). Paper claim (§8.2.2):
Capybara's throughput scales linearly with the server count, while the software switch
caps at about one million requests per second.

## Run

SSH to **node7**, then:

```bash
bash ~/capybara-AE-runs/fig13/run_fig13.sh quick   # 1 / 4 / 12 servers, ~25 min
bash ~/capybara-AE-runs/fig13/run_fig13.sh         # 1 / 2 / 4 / 8 / 12 servers, ~40 min (the figure)
```

## Output

- `fig13_reproduction.png` / `.pdf` — the paper-layout figure (this run's data only)
- `results_fig13.txt` — one `RES fig13 hw|sw servers=<N> ... peak_rps=<r>` line per cell
- The console prints a paper-vs-ours table (millions of requests/s).

## What to expect (AE criterion: same behavior pattern, not exact values)

Capybara (Tofino switch), peak requests/s with p99 under 1 ms, paper / this testbed
(quick run of 2026-10-04):

| servers | 1 | 2 | 4 | 8 | 12 |
|---|---|---|---|---|---|
| paper | 0.54 M | 1.20 M | 2.60 M | 5.59 M | 8.36 M |
| this testbed | **0.55-0.65 M** | ~1.2 M | **2.1-2.6 M** | ~4.5-5.5 M | **6.3-7.0 M** |

The pattern to check is the linear growth with the server count. The 12-server cell is
limited by what the three client machines can offer (about 7 M requests/s at this response
size), so it lands below the paper's 8.4 M; the 1-, 2- and 4-server cells are server-bound
and match the paper.

**Capybara-SW column.** The runner contains the software-switch path
(`fig13_sw_bringup.sh`, `run_fig13_sw_one.sh`; enable with `SKIP_SW=0`), rebuilt from the
paper-era tree exactly as the 2024 driver ran it, but on the current testbed the software
switch does not forward connections (its rewritten SYNs never leave node8), so the column is
not produced by default. The paper's measurement for it is a flat ~0.96 M requests/s from two
servers on (the single-core switch is the bottleneck), 0.50 M with one server.

## How it works

- **Capybara (hardware switch)**: the Fig 10 setup (`main_eval_fig10` switch program with
  12 backends on node8/9/10, three caladan clients with 720 connections). For N servers the
  clients spread a uniform open-loop load over the first N server groups only
  (`gen_spec.py topN`); the offered load is stepped up and the cell's value is the highest
  rung whose p99 stays under 1 ms (the peak criterion used for Fig 10).
- **Capybara-SW**: the switch runs a plain L2 program (`endhost_switch`); node8 runs
  `capybara-switch.elf`, Capybara's software switch, on one core. New connections are
  round-robined over the first N entries of its built-in backend table (node8/9/10 ×
  ports 10000-10003, the same layout as the hardware setup). The backends are the
  paper-era tree (`~/Capybara/capybara-fig14tls`, commit `4599b186` of 2024-12-08, the day
  these measurements were taken for the paper) built with `tcp-migration,capy-time-log`;
  node8's backends attach to the software switch as DPDK secondaries, node9/10 run their
  own `dpdk-ctrl`. One open-loop caladan client on node7 with 128 connections steps the
  offered load; same peak criterion. The 2024 driver (`eval/run_eval.py`,
  `SERVER_APP = 'capybara-switch'`) and its saved configurations in `~/capybara-data`
  (2024-12-08) are what this runner follows.
- Responses are 256 B. The 12-server Capybara cell is close to what the three clients
  can offer; see the expected-values table.
