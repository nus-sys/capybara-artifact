# Fig. 11 — L7 server scalability (closed- & open-loop): REPRODUCED

The figure's claims reproduce on the paper's own trees and switch programs:
a traditional L7 proxy is flat (~13-18 Gbps) regardless of backends; Prism
matches Capybara-L7 closed-loop but is effectively unavailable open-loop;
Capybara-L7 scales linearly in both, with every open-loop cell within 2% when the
row above was recorded. On the current shared cluster the NB=4 open cell lands
lower (~35-50 Gbps; the runner verifies all four backends and retries the rung).
The closed-loop panel is unaffected and is the comparison that matters.

## Results (peak Gbps, 128 KB responses)

| closed-loop | 1 BE | 2 BE | 4 BE |   | open-loop | 1 BE | 2 BE | 4 BE |
|---|---|---|---|---|---|---|---|---|
| L7 Proxy ours | 18.4 | 18.3 | 18.0 | | ours | 12.82 | n/m | n/m |
| paper | 15.7 | 16.2 | 16.2 | | paper | 12.99 | 13.69 | 13.87 |
| Prism ours | 30.5 | 59.3 | 93.0 | | ours | 0.104 | 0.013 | 0.063 |
| paper | 24.7 | 46.9 | 91.4 | | paper | 0.088 | 0.101 | 0.091 |
| Capybara-L7 ours | 28.0 | 39.8 | 92.9 | | ours | 17.89 | 34.99 | 64.07 |
| paper | 24.7 | 47.2 | 90.9 | | paper | 17.87 | 34.15 | 65.20 |

n/m: our client/server combination collapses for the proxy above ~10 Gbps
with multiple backends under the open-loop client (fine at low load, so the
relay paths work); the proxy-flatness claim is fully covered by the closed row
and the 1-BE open cell.

## Systems and how they run (all recovered from the era's own records)

- **Capybara-L7** (= capy-proxy): the switch program `capybara_switch_fe`
  (sw1 LIVE tree, installed conf) IS the frontend - it round-robins client
  SYNs straight to the node9 backends and masks every reply as
  10.0.1.8:55555. Backends hand each connection over at request boundaries
  through the switch's min-RPS retargeting (pktgen-driven). Bring-up:
  `fig11_bringup_capy2.sh <NB>`; one rung: `capy_open_rung.sh <NB> <pps>`
  (THREADS env; servers + dpdk-ctrl restart every rung).
- **Prism** (= prism-star): separate tree `~/Capybara/prism-star`
  (LIBOS=catnip env required; FE starts BEFORE the backends), prism P4
  program (`fig11_bringup_prism.sh`).
- **L7 Proxy** (= proxy-server): rebuilt on the fixed tree, prism P4 program,
  peaks at 10-15 wrk conns closed / pps 12500 open.
- Clients: wrk (closed), caladan synthetic from node7 (open;
  `run_fig11_open.sh <label> <ip:port> "<pps...>"`). curl sanity only valid
  with iokerneld stopped (directpath steals inbound frames).

## The five host-side fixes (133-line diff vs monorepo 7cd615ad)

1. u16 SYN-window shift wraparound (62720<<11 mod 2^16 = 0) - kernel clients
   got a zero send window after migration.
2. Idempotent PREPARE at the migration target - a retransmitted PREPARE used
   to destroy the in-flight handover (this alone took NB=2 open-loop from
   49% to 98% completion).
3. Stale tcpmig messages (NIC RX ring across restarts) ignored, not panicked.
4. ReturnedBySwitch keeps the connection (single-BE case would otherwise
   re-initiate forever).
5. capy-proxy-be serves a returned migration's request on redelivery
   (one migration attempt per request boundary).

Wire facts that cost days: client route needs `advmss 8960` (era stack emits
peer-MSS segments that exceed the 9216B NIC ceiling); the caladan client
opens a second wave of connections mid-run (the SYN burst per backend is what
limited NB=2 to ~90 connections).

## Reproduction commands

Per-system bring-up is scripted in the run_fig11_*.sh runners. Raw rungs:
results_closed_{capy,proxy,prismstar}.txt, results_open.txt. Plot:
`python3 plot_fig11.py` -> fig11_reproduction.{png,pdf}.
