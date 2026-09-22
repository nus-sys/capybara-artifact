# Source provenance for the artifact evaluation

Every measurement in `AE/` was produced by a specific host-stack tree, client
tree, and switch program. This file maps each figure to those exact sources so
that the runners on the testbed and the code in this repository can be checked
against each other. The `main` branch of this repository is the source release;
the per-figure host trees live on the `ae-fig*` branches of the same repository,
and each branch's small uncommitted working-tree adjustments (paths, toggles)
are recorded verbatim under `worktree-diffs/`.

`manifests/<figN>/` is a copy of the frozen-state manifests kept next to each
runner on the testbed: source diffs, `.state` files (branch + HEAD at freeze
time) and `bin.md5` (checksums of the binaries the reviewer commands run).

## Host stack (this repository, github.com/nus-sys/capybara-artifact)

| Figure | Branch / commit | Working-tree diff | Frozen manifest |
|---|---|---|---|
| Fig 7 | `ae-fig7` @ `1cb01046` | `worktree-diffs/capybara.diff` | `manifests/fig7/server-capybara.diff` |
| Fig 8 | `ae-fig8` @ `391e1a3e` | `worktree-diffs/capybara-fig8.diff` | `manifests/fig8/server-capybara-fig8.diff` |
| Fig 9 | `ae-fig9` @ `77053409` (includes `shim/`) | `worktree-diffs/capybara-fig9.diff` | `manifests/fig9/server-capybara-fig9.diff` |
| Fig 10 | `ae-fig10` @ `a6bfd0a5` | `worktree-diffs/capybara-fig10.diff` | `manifests/fig10/server-capybara-fig10.diff` |
| Fig 11 | commit `7cd615ad` (in history) | — | `manifests/fig11/capybara-fig11-vs-7cd615ad.diff` |
| Fig 12 (bonus) | commit `b62db412` (in history) | `worktree-diffs/capybara-fig12.diff` | — |
| Fig 14, TCP panel | `ae-fig10` @ `a6bfd0a5` | — | `manifests/fig14/source.diff` (base in `base-commit.txt`) |
| Fig 14, TLS panel | commit `4599b186` (in history, the paper-era tree) | `worktree-diffs/capybara-fig14tls.diff` | `manifests/fig14/papertree-source.diff` |

All four `ae-fig*` branches fork from `bfcfc09b` (the `shim` line of the
codebase, which is what the servers ran for the paper); each adds one commit with
the figure-specific change described in its commit message.

`worktree-diffs/HEADS.txt` lists the HEAD of every tree on the testbed at the
time this snapshot was taken (2026-09-22).

## Other host-side components

| Component | Repository | Commit / branch | Local changes |
|---|---|---|---|
| Redis (Fig 9) | github.com/nus-sys/capybara-redis | `capybara` @ `e12fe87d2` | `worktree-diffs/capybara-redis.diff` (node config) |
| Prism (Fig 11 baseline) | github.com/nus-sys/capybara | `prism-star` @ `c63e7dbc` | `manifests/fig11/prism-star-worktree.diff` |
| L7 proxy (Fig 11) | this repository | `examples/rust/proxy-server-{fe,be}.rs` on `7cd615ad` | in the Fig 11 diff above |
| wrk / wrk2 (Fig 11 load) | github.com/wg/wrk, github.com/giltene/wrk2 | upstream | none |

## Load generator (Caladan fork, github.com/ihchoi12/caladan)

| Used by | Branch / commit | Notes |
|---|---|---|
| Fig 7 main client (node7) | `ae-fig7-client` @ `dc4f25e` | short-flow connections reset instead of closed; frozen diff in `manifests/fig7/client-node7-caladan.diff` |
| Fig 7 short-flow client (node6) | `ae-fig7-client-n6` @ `c3e7739` | `manifests/fig7/client-node6-caladan.diff` |
| Fig 8 / 9 / 10 / 14 client | `capybara-client` + `../patches/caladan-fig8.patch` | same content as `manifests/fig8/client-caladan-fig8.diff`; server-reply-analysis build |
| Fig 10 node6 client | `ae-fig10-client-n6` @ `750011e` | jumbo frames; `manifests/fig10/client-caladan-n6-jumbo.diff` |
| Fig 10 client configs | `../patches/client_node{6,7}_fig10.config` | 24 kthreads, MTU 9000 |

## Switch programs (Intel Tofino, SDE 9.4.0)

The compiled programs on the switch and the sources they were built from:

| Figure | Program | Source in this repository | Control plane |
|---|---|---|---|
| Fig 7 | `main_eval` | `p4/switch_fe/main_eval.p4` | `p4/switch_fe/main_eval_setup.py`, `main_eval_pktgen_timer.py`; ports via `switch/fig7/port_add.py` |
| Fig 8, Fig 9 | `main_eval_fig8` | `switch/fig8/main_eval_fig8.p4` | `switch/fig8/main_eval_fig8_setup.py`, `main_eval_pktgen_timer_1ms.py` |
| Fig 10 | `main_eval_fig10` | `switch/fig10/main_eval_fig10.p4` | `switch/fig10/main_eval_fig10_setup.py`, `port_add_jumbo.py`, `patch_beidx.py` |
| Fig 11 | `capybara_switch_fe_fig11`, `prism` | `switch/fig11/p4/switch_fe/capybara_switch_fe_fig11.p4`, `switch/fig11/p4/prism/prism.p4` | `switch/fig11/setup_fig11.py`, `overlay_*.py`, `setup_port_mirror_fig11.py` |
| Fig 14 | `port_forward` (idle baseline) | `p4/port_forward/port_forward.p4` | `switch/fig14/main_eval_fig14_setup.py` |
| idle | `port_forward` | `p4/port_forward/port_forward.p4` | `p4/port_forward/port_forward.py` |

`switch/fig11/p4/` is the whole P4 tree as it exists on the switch for the Fig 11
build (it predates some of the `p4/` files on `main`); only
`capybara_switch_fe_fig11.p4` is new relative to `p4/`.

## Binaries

`manifests/<figN>/bin.md5` (and `binaries.md5` for Fig 11) checksum the exact
binaries the runners execute from `/homes/inho/` on the testbed, so a reviewer can
confirm that what runs matches what is described here.
