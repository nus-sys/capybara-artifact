# Capybara: Dynamic Load Balancing with Microsecond-Scale TCP Migration

Source release for the SIGCOMM 2026 paper. Capybara is an L4 load balancer
that rebalances established TCP connections through microsecond-scale live
connection migration, co-designed between a P4 programmable switch and a
kernel-bypass host stack (built on [Demikernel](https://github.com/microsoft/demikernel)).

## Layout

| Path | Contents |
|---|---|
| `src/` | the Capybara host stack (Rust): TCP/IP stack, migration protocol, transport interface |
| `p4/` | Tofino switch programs (L4 load balancing, migration co-design, per-figure eval variants) |
| `examples/` | applications used in the evaluation (HTTP server, proxy, Redis shim glue) |
| `eval/`, `scripts/` | evaluation and data-processing scripts |
| `config/` | per-host configuration templates |

## Building

The host stack builds with the standard Demikernel toolchain (Rust nightly per
`rust-toolchain`, DPDK with the mlx5 PMD; see `Makefile`). The switch programs
target Intel Tofino, Barefoot SDE 9.4.

## Reproducing the paper's results

The evaluation requires a physical testbed: a Tofino switch (APS BF6064X-T)
and six servers with Mellanox ConnectX-5 100 GbE NICs. It is not reproducible
on virtual hardware. For SIGCOMM'26 artifact evaluation, reviewers receive SSH
access to the authors' testbed, where a run kit maps each paper claim to a
one-command runner; access instructions are provided through the AE
submission. Anyone with equivalent hardware can adapt the switch programs and
scripts in this release.

On the testbed, each figure is one command from `~/capybara-AE-runs/`
(its README has the full expected tables and tolerances):

| Claim (from the abstract) | Figure | Command | Time |
|---|---|---|---|
| Up to 149x lower p99 tail latency under skew | Fig 7 | `bash fig7/run_fig7.sh quick` (or `full`) | ~18 / 45 min |
| Continuous rebalancing vs reactive/static | Fig 8 | `bash fig8/run_fig8.sh` | ~6 min |
| Works for stateful Redis (POSIX shim) | Fig 9 | `bash fig9/run_fig9.sh` | ~6 min |
| >2x throughput at 12 servers under skew | Fig 10 | `bash fig10/run_fig10.sh quick` (or `full`) | ~33 / 80 min |
| Benefits L7 LB; Prism collapses open-loop | Fig 11 | `bash fig11/run_fig11.sh` (or `full`) | ~34 / 65 min |
| Migration <3 us CPU, <15 us e2e; TCP+TLS | Fig 14 | `bash fig14/run_fig14.sh` | ~9 min |

Each runner brings up the switch program and host stacks it needs, runs the
experiment, regenerates the figure with the paper's own plotting code from
that run's data, and restores the cluster to a clean baseline.

## License

See `LICENSE.txt` (this release follows the licensing of the Demikernel
codebase it builds on; see also `NOTICE.md`).
