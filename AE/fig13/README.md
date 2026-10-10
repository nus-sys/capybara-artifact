# Fig. 13 — peak throughput vs number of servers: Capybara vs Capybara-SW

Reproduces Fig. 13 (`server_scalability_l4`): peak request rate with 1, 2, 4, 8 and 12
servers, for Capybara on the Tofino switch and for Capybara-SW, the same load balancer
implemented as a DPDK software switch on an end host (one core). Paper claim (§8.2.2):
Capybara's throughput scales linearly with the server count, while the software switch
caps at about one million requests per second.

## Run

SSH to **node7**, then:

```bash
bash ~/capybara-AE-runs/fig13/run_fig13.sh quick   # 1 / 4 / 12 servers, both columns, ~35 min
bash ~/capybara-AE-runs/fig13/run_fig13.sh         # 1 / 2 / 4 / 8 / 12 servers, ~60 min (the figure)
```

## Output

- `fig13_reproduction.png` / `.pdf` — the paper-layout figure (this run's data only)
- `results_fig13.txt` — one `RES fig13 hw|sw servers=<N> ... peak_rps=<r>` line per cell
- The console prints a paper-vs-ours table (millions of requests/s).

## What to expect (AE criterion: same behavior pattern, not exact values)

Peak requests/s (millions), paper / this testbed (full run of 2026-10-04: Capybara 0.54 / 1.14 / 2.15 / 4.46 / 6.68, Capybara-SW 0.57 / 0.86 / 0.86 / 0.86 / 1.01):

| servers | 1 | 2 | 4 | 8 | 12 |
|---|---|---|---|---|---|
| Capybara, paper | 0.54 | 1.20 | 2.60 | 5.59 | 8.36 |
| Capybara, this testbed | **0.50-0.65** | 1.1-1.3 | **2.1-2.6** | 4.3-5.0 | **6.3-7.0** |
| Capybara-SW, paper | 0.50 | 0.96 | 0.96 | 0.96 | 0.96 |
| Capybara-SW, this testbed | **0.55-0.60** | 0.83-1.05 | **0.83-1.05** | 0.83-1.05 | **0.83-1.05** |

The pattern to check: Capybara grows linearly with the server count, Capybara-SW is flat
from two servers on (its single-core software switch saturates at 0.85-1.0 M requests/s;
with one server both are bound by that server, ~0.55 M here). The 12-server Capybara cell is
limited by what the three client machines can offer (about 7 M requests/s at this response
size), so it lands below the paper's 8.4 M; the 1-, 2- and 4-server cells are server-bound and
match the paper (the 8-server cell sits in between for the same reason).

How the peak is determined: the offered load is stepped up rung by rung (3 s each); the
cell is the highest achieved rate with p99 under 1 ms while the achieved rate still grows
with the offered load. The offered/achieved ratio is deliberately not a criterion: the load
generators' timer-paced send threads skip part of their schedule as "late" at low per-client
rates (10-25% on node5/6, also on the hardware path), which is a client property, not server
saturation. When a server or the software switch saturates, p99 jumps past the limit or the
next rung collapses (connections time out), and the ladder stops there.

## How it works

- **Capybara (hardware switch)**: the Fig 10 setup (`main_eval_fig10` switch program with
  12 backends on node8/9/10, three caladan clients with 720 connections). For N servers the
  clients spread a uniform open-loop load over the first N server groups only
  (`gen_spec.py topN`); the offered load is stepped up and the cell's value is the highest
  achieved rate whose p99 stays under 1 ms (see above).
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
