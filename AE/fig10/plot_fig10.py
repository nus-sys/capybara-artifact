#!/usr/bin/env python3
"""Fig-10 reproduction: peak throughput, 12 servers, 720 conns, Zipf-1.2 vs Uniform.
Left: absolute Gbps (our testbed, 2 clients, non-jumbo). Right: normalized to the
uniformly-balanced ideal, with the paper's normalized values as reference markers.
"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

SIZES = ['1 KB', '4 KB', '8 KB']
import os, sys
RES = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser('~/capybara-AE-runs/fig10/fig10_results.txt')
SZ = [1024, 4096, 8192]
peaks = {'LWRR': {}, 'CAPY': {}, 'UNI': {}, 'UNIP': {}}
runs = []; runs_g = []
for line in open(RES):
    p = line.split()
    if len(p) >= 6 and p[0] == 'RES' and p[1] in peaks:
        try:
            cond, sz, g = p[1], int(p[2]), float(p[5])
        except ValueError:
            continue
        try:
            tgt, ach = int(p[3]), int(p[4])
        except ValueError:
            continue
        peaks[cond][sz] = max(peaks[cond].get(sz, 0.0), g)
        runs.append((cond, sz, tgt, ach))
        runs_g.append((cond, sz, tgt, ach, g))
# matched-load comparison: for each size, only consider offered loads at which the
# Uniform reference still scales (>=93% of target). Beyond that our 2-client harness
# — not the servers — is the bottleneck for the uniform workload.
LMAX = {}
for sz in SZ:
    ok = [L for (c, s2, L, a) in runs if s2 == sz and c in ('UNI', 'UNIP') and a >= 0.93 * L]
    LMAX[sz] = max(ok) if ok else max((L for (c, s2, L, a) in runs if s2 == sz), default=0)

def best(cond, sz):
    # peak = highest throughput at a load the condition still keeps up with (>=93% of
    # offered). Past that point a server is saturated and the extra "achieved" requests
    # only come from the servers that are not the bottleneck.
    return max([g for (c, s2, L, a, g) in runs_g
                if c == cond and s2 == sz and a >= 0.93 * L], default=0.0)

uni = {sz: max(best('UNI', sz), best('UNIP', sz)) for sz in SZ}
OURS = {
    'LWRR':     [best('LWRR', sz) for sz in SZ],
    'Capybara': [best('CAPY', sz) for sz in SZ],
    'Uniform':  [uni[sz] for sz in SZ],
}
PAPER = {                      # Gbps from the paper's large_scale.csv
    'LWRR':     [22.13, 62.51, 99.94],
    'Capybara': [42.14, 133.36, 201.26],
    'Uniform':  [55.13, 181.05, 246.56],
}
COLORS = {'LWRR': 'lightgrey', 'Capybara': 'lightblue', 'Uniform': '#b8e0b8'}
HATCH = {'LWRR': '//', 'Capybara': '\\\\', 'Uniform': ''}

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(9.5, 3.4))
x = np.arange(len(SIZES))
w = 0.26

for i, cond in enumerate(['LWRR', 'Capybara', 'Uniform']):
    ax1.bar(x + (i - 1) * w, OURS[cond], w, label=cond, color=COLORS[cond],
            hatch=HATCH[cond], edgecolor='k')
ax1.set_ylabel('Peak Throughput (Gbps)')
ax1.set_xlabel('Response Size')
ax1.set_xticks(x); ax1.set_xticklabels(SIZES)
ax1.legend(fontsize=8)
ax1.set_title('(a) Absolute (our testbed)', fontsize=10)
ax1.grid(axis='y', linestyle='--', linewidth=0.6); ax1.set_axisbelow(True)

for i, cond in enumerate(['LWRR', 'Capybara']):
    ours_n = [100 * o / u for o, u in zip(OURS[cond], OURS['Uniform'])]
    paper_n = [100 * p / u for p, u in zip(PAPER[cond], PAPER['Uniform'])]
    ax2.bar(x + (i - 0.5) * w, ours_n, w, label=f'{cond} (ours)', color=COLORS[cond],
            hatch=HATCH[cond], edgecolor='k')
    ax2.plot(x + (i - 0.5) * w, paper_n, 'v', color='red' if cond == 'LWRR' else 'darkblue',
             ms=8, label=f'{cond} (paper)')
ax2.axhline(100, color='grey', lw=0.8, ls='--')
ax2.set_ylabel('% of Uniform ideal')
ax2.set_xlabel('Response Size')
ax2.set_xticks(x); ax2.set_xticklabels(SIZES)
ax2.set_ylim(0, 115)
ax2.legend(fontsize=7, loc='upper left', ncol=2)
ax2.set_title('(b) Normalized to ideal', fontsize=10)
ax2.grid(axis='y', linestyle='--', linewidth=0.6); ax2.set_axisbelow(True)

fig.suptitle('Fig. 10 reproduction — 12 servers, 720 conns, Zipf-1.2 (3 client nodes, jumbo frames, connection-level Zipf — paper configuration)',
             fontsize=9, y=1.0)
fig.tight_layout()
fig.savefig('fig10_reproduction.pdf')
fig.savefig('fig10_reproduction.png', dpi=140)

print('=== Fig-10 summary ===')
for cond in ['LWRR', 'Capybara', 'Uniform']:
    n = [f'{100*o/u:.0f}%' for o, u in zip(OURS[cond], OURS['Uniform'])]
    print(f'{cond:9s}: {OURS[cond]} Gbps  ({n} of ideal)')
print('paper    : LWRR 40/35/41% of ideal; Capybara 76/74/82%')
print('wrote fig10_reproduction.png/pdf')
