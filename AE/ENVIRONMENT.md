# Environment — hardware and software the artifact runs on

Reviewers evaluate on **our testbed** (access via HotCRP), where everything below
is already installed, built, and configured. This file documents the environment
for completeness (the "Documented" / "Complete" criteria) and for anyone who wants
to understand or replicate the setup on their own hardware. You do **not** need to
install any of this to evaluate — the tester account is pre-built.

## Topology

```
              +------------------------- Intel Tofino switch (sw1) -------------------------+
              |  APS Networks BF6064X-T, 100 GbE, Tofino SDE 9.4.0, program: main_eval_*    |
              +----------------------------------------------------------------------------+
                 |            |            |            |            |            |
             node5        node6        node7        node8        node9       node10
            (client)     (client)   (client +      (server)     (server)    (server)
                                    orchestrator)
```

- 6 x86 servers + 1 programmable switch, all on a 100 GbE fabric.
- **node7** is the orchestration host: every `run_figN.sh` is launched from here.
- Servers (node8/9/10) run the Capybara kernel-bypass stack; clients (node5/6/7)
  run the load generators. Roles are fixed by the run scripts.

## Servers — node7/8/9/10

| Component | Spec |
|---|---|
| CPU | Intel Xeon Gold 6326 @ 2.90 GHz, 2 sockets, 64 threads, 2 NUMA nodes |
| NIC | Mellanox ConnectX-5 (MT27800), 100 GbE, PCIe `31:00.x` |
| OS | Ubuntu 22.04.5 LTS, kernel 5.15.0 |
| OFED | MLNX_OFED 24.10-5.1.6.1 |
| Dataplane | DPDK (mlx5 PMD) via the Capybara stack; hugepages (2 MB) preallocated |

## Clients — node5/6

| Component | Spec |
|---|---|
| CPU | Intel Xeon Gold 6230 @ 2.10 GHz |
| NIC | Mellanox ConnectX-5, 100 GbE (node5 PCIe `b3:00.0`) |
| OFED | node5: MLNX_OFED 5.7-1.0.2.0; node6: 5.4-3.5.8.0 |
| Load gen | Caladan-based `synthetic` client (closed/open loop), plus `wrk` for Fig 11 |

(node7 also acts as a third client; being the only 2-NUMA client it gets a small
hugepage adjustment inside `fig10_bringup.sh`, auto-reverted by `cleanup_all.sh`.)

## Switch — sw1

| Component | Spec |
|---|---|
| Model | APS Networks BF6064X-T (Intel Tofino), 100 GbE |
| SDE | Barefoot/Intel SDE 9.4.0 (`/home/singtel/bf-sde-9.4.0`) |
| Programs | `main_eval_*` (L4 eval), `capybara_switch_fe` (Fig 11 L7), `port_forward` (idle baseline) |
| Control plane | `run_bfshell.sh` / `run_pd_rpc` scripts paired with each program |

Only **one** switch program (`bf_switchd`) runs at a time; each runner installs the
program it needs and reverts to the `port_forward` baseline on cleanup.

## Software the artifact ships / uses

- **Capybara stack**: kernel-bypass host stack (Demikernel-based) + P4 switch programs,
  pre-built under `/homes/inho/` (paths baked into the run scripts, read-only to reviewers).
- **Plotting**: Python 3 with `pandas`, `numpy`, `matplotlib`, `brokenaxes`.
  These are vendored in the kit under `pyenv-lib/` (installed with `pip --target`, since
  node7 has no venv/ensurepip); the plot scripts add it to `sys.path` automatically, so
  **no reviewer action is needed**. To plot on a different machine, install those four
  packages (see `requirements.txt`). Figures are rendered by the paper's own plotting
  code (`paperplot/create_plots.py`, an unmodified copy of the repository's `graphs/
  create_plots.py`), so the output matches the paper's figures directly.

## Not reproducible on virtual hardware

The results depend on the physical Tofino switch and 100 GbE NICs; they cannot be
reproduced in a VM or on cloud instances. This is why reviewer access is
to the authors' testbed. The complete source is published at
https://github.com/nus-sys/capybara-artifact (release `sigcomm26-ae-v1.0`, with this kit
under `AE/`) for inspection and for anyone with equivalent hardware.
