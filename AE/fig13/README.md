# Fig. 13 — peak throughput vs number of servers: Capybara vs Capybara-SW

Reproduces Fig. 13 (`server_scalability_l4`): peak request rate with 1, 2, 4, 8 and 12
servers, for Capybara on the Tofino switch and for Capybara-SW, the same load balancer
implemented as a DPDK software switch on an end host (one core). Paper claim (§8.2.2):
Capybara's throughput scales linearly with the server count, while the software switch
caps at about one million requests per second.

## Run

SSH to **node7**, then:

```bash
bash ~/capybara-AE-runs/fig13/run_fig13.sh quick   # 1 / 4 / 12 servers, both columns, ~30 min
bash ~/capybara-AE-runs/fig13/run_fig13.sh         # 1 / 2 / 4 / 8 / 12 servers, ~50 min (the figure)
```

## Output

- `fig13_reproduction.png` / `.pdf` — the paper-layout figure (this run's data only)
- `results_fig13.txt` — one `RES fig13 hw|sw servers=<N> ... peak_rps=<r>` line per cell
- The console prints a paper-vs-ours table (millions of requests/s).

## What to expect (AE criterion: same behavior pattern, not exact values)

Peak requests/s (millions), paper / this testbed (runs of 2026-10-04):

| servers | 1 | 2 | 4 | 8 | 12 |
|---|---|---|---|---|---|
| Capybara, paper | 0.54 | 1.20 | 2.60 | 5.59 | 8.36 |
| Capybara, this testbed | **0.55-0.65** | ~1.2 | **2.1-2.6** | ~4.5-5.5 | **6.3-7.0** |
| Capybara-SW, paper | 0.50 | 0.96 | 0.96 | 0.96 | 0.96 |
| Capybara-SW, this testbed | **0.55-0.60** | ~0.85 | **0.83-0.90** | ~0.85 | **0.83-0.90** |

The pattern to check: Capybara grows linearly with the server count, Capybara-SW is flat
from a few servers on (its single-core software switch saturates at about 0.9 M requests/s;
with one server both are bound by that server, ~0.6 M here). The 12-server Capybara cell is
limited by what the three client machines can offer (about 7 M requests/s at this response
size), so it lands below the paper's 8.4 M; the 1-, 2- and 4-server cells are server-bound and
match the paper.

How the peak is determined: the offered load is stepped up rung by rung. For Capybara the cell
is the highest rung whose p99 stays under 1 ms and whose achieved rate is at least 90% of the
offered one (the Fig 10 criterion). For Capybara-SW the two load generators deliver about 90%
of their nominal schedule even when nothing is saturated, so the cell is the highest
*achieved* rate with p99 under 1 ms; when the software switch saturates, the next rung
collapses (connections time out) and the ladder stops there.

## How it works

- **Capybara (hardware switch)**: the Fig 10 setup (`main_eval_fig10` switch program with
  12 backends on node8/9/10, three caladan clients with 720 connections). For N servers the
  clients spread a uniform open-loop load over the first N server groups only
  (`gen_spec.py topN`); the offered load is stepped up and the cell's value is the highest
  rung whose p99 stays under 1 ms (the peak criterion used for Fig 10).
- **Capybara-SW**: the Tofino runs a plain L2 program (`endhost_switch`): every frame that
  does not come from node7 is sent to node7, frames from node7 are forwarded by MAC. node7
  runs Capybara's software switch (`capybara-switch`, one core), which assigns new
  connections round-robin to the first N entries of its backend table (node8/9/10 × ports
  10000-10003) and rewrites both directions (client → backend, backend replies → the VIP
  10.0.1.7:10000). The switch is the paper-era tree (`~/Capybara/capybara-fig13sw`, commit
  `4599b186` of 2024-12-08, the day these measurements were taken for the paper) built with
  the `capybara-switch` feature; `patches/capybara-switch-12-backends.diff` is the whole
  source change on top of that commit (the backend table for this testbed, and two
  robustness fixes: a retransmitted SYN is sent to the backend that already owns the
  connection instead of panicking, and packets of unknown connections are dropped instead
  of panicking). The backends are the Fig 10 server tree without reply rewriting
  (`~/Capybara/capybara-fig13be`), attached to a `dpdk-ctrl` primary per node that is
  restarted for every measurement. Two open-loop caladan clients on node5/6 (240 connections
  each, the Fig 10 client form) share the offered load; node7's NIC belongs to the switch,
  so it is not a client here.
- Responses are 256 B. The 12-server Capybara cell is close to what the three clients
  can offer; see the expected-values table.
