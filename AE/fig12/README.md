# Fig. 12 — connection scalability (bonus, author-verified)

Sustained throughput as the number of concurrent connections grows, up to
193,536 connections. This is a bonus result beyond the six main-claim figures.
All three curves of the paper's Figure 12 reproduce on this testbed:

- **Demikernel** — the baseline stack, no migration.
- **Capybara-Switch** — connections migrate during the run; tracks Demikernel,
  so migration adds no datapath cost.
- **Capybara** — migration plus per-I/O-poll load monitoring; the O(connections)
  monitoring cost pulls throughput down past ~40K connections.

`fig12_reproduction.png` (this directory) is the reproduced figure.

## Result (throughput, reqs/s)

| connections | Demikernel | Capybara-Switch | Capybara |
|---|---|---|---|
| 144     | 2,391,790 | 2,394,307 | 2,350,008 |
| 14,400  | 2,339,858 | 2,337,870 | 2,335,161 |
| 72,000  | 2,196,630 | 2,196,859 | 1,586,835 |
| 158,400 | 1,710,989 | 1,671,043 |   949,160 |
| 193,536 | 1,504,064 | 1,463,825 |   811,251 |

Demikernel and Capybara-Switch stay together across the whole range; Capybara
falls away once the connection count is high enough for the monitoring pass to
dominate. The shapes match the paper's Fig. 12; absolute numbers are a little
below the paper's on this hardware, and the relationship between the curves is
what the figure is about.

## How it was reproduced

The three curves come from one server binary built three ways from the
`~/Capybara/capybara-fig12` tree (records in this directory + the tree):

- **Demikernel**: server-rewriting build, migration disabled (`MIG_PER_N=0`).
- **Capybara-Switch**: `server-rewriting,tcp-migration,manual-tcp-migration`
  with the per-poll monitoring call (`inetstack/mod.rs` `poll_stats()`) removed;
  servers migrate on a `MIG_PER_N` time gate; the switch runs
  `capybara_switch_fe_src_rewriting_by_server` with the min-rps target seeded.
- **Capybara**: same as Capybara-Switch but with `poll_stats()` left in (the
  monitoring pass runs every I/O poll).

Migration needed the `tcpmig/peer.rs` handling from the L7 work (a retransmitted
PREPARE for an in-flight migration is re-acked instead of tearing the handover
down); without it the migrated connections stall. Driver:
`run_fig12_curve2.sh "<per-proc conns>" <MIG_PER_N_us>`; ladder builder and the
plot script are in this directory.
