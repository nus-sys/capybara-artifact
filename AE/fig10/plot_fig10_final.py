#!/usr/bin/env python3
"""Fig-10 reproduction, all five response sizes.

Peak throughput = the highest offered load whose p99 is still sane (<= 1 ms).
That is how the paper's own spreadsheets picked their operating points: rows
with a latency blow-up were discarded, rows the client could not fully drive
were kept.

Segmentation note: responses larger than one jumbo frame need MSS 8960, not
9000. With MSS 9000 a full segment plus the 40 B IP/TCP header is 9040 B, past
the 9000 B path MTU, so every multi-segment response pays an extra round of
fragmentation. 1-8 KB responses fit in a single segment and are unaffected.
"""
import os, sys, re
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

RES = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    '~/capybara-AE-runs/fig10/fig10_results_mss8960.txt')
P99_LIMIT = 1000.0
SZ = [1024, 4096, 8192, 16384, 20480]
SIZES = ['1 KB', '4 KB', '8 KB', '16 KB', '20 KB']

best = {}
for line in open(RES):
    m = re.match(r'RES (\w+) (\d+) (\d+) (\d+) ([\d.]+) p99=(\d+)', line.strip())
    if not m:
        continue
    cond, sz, ach, g, p99 = m.group(1), int(m.group(2)), int(m.group(4)), float(m.group(5)), float(m.group(6))
    if p99 > P99_LIMIT:
        continue
    if g > best.get((cond, sz), 0.0):
        best[(cond, sz)] = g

OURS = {
    'LWRR':     [best.get(('LWRR', s), 0.0) for s in SZ],
    'Capybara': [best.get(('CAPY', s), 0.0) for s in SZ],
    'Uniform':  [best.get(('UNI', s), 0.0) for s in SZ],
}
PAPER = {
    'LWRR':     [22.13, 62.51, 99.94, 106.96, 108.08],
    'Capybara': [42.14, 133.36, 201.26, 191.91, 191.91],
    'Uniform':  [55.13, 181.05, 246.56, 229.46, 216.54],
}
COLORS = {'LWRR': 'lightgrey', 'Capybara': 'lightblue', 'Uniform': '#b8e0b8'}
HATCH = {'LWRR': '//', 'Capybara': '\\\\', 'Uniform': ''}

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 3.5))
x = np.arange(len(SIZES)); w = 0.26

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
    ours_n = [100 * o / u if u else 0 for o, u in zip(OURS[cond], OURS['Uniform'])]
    paper_n = [100 * p / u for p, u in zip(PAPER[cond], PAPER['Uniform'])]
    ax2.bar(x + (i - 0.5) * w, ours_n, w, label=f'{cond} (ours)', color=COLORS[cond],
            hatch=HATCH[cond], edgecolor='k')
    ax2.plot(x + (i - 0.5) * w, paper_n, 'v', color='red' if cond == 'LWRR' else 'darkblue',
             ms=8, label=f'{cond} (paper)', linestyle='none')
ax2.axhline(100, color='grey', lw=0.8, ls='--')
ax2.set_ylabel('% of Uniform ideal')
ax2.set_xlabel('Response Size')
ax2.set_xticks(x); ax2.set_xticklabels(SIZES)
ax2.set_ylim(0, 118)
ax2.legend(fontsize=7, loc='upper left', ncol=2)
ax2.set_title('(b) Normalized to ideal (markers = paper)', fontsize=10)
ax2.grid(axis='y', linestyle='--', linewidth=0.6); ax2.set_axisbelow(True)

fig.suptitle('Fig. 10 reproduction - 12 servers, 720 conns, Zipf-1.2 over connections, '
             '3 clients, jumbo frames; peak = highest load with p99 <= 1 ms',
             fontsize=8.5, y=1.0)
fig.tight_layout()
fig.savefig('fig10_reproduction.pdf')
fig.savefig('fig10_reproduction.png', dpi=140)

print('=== Fig-10 summary (peak at p99 <= 1 ms) ===')
print(f'{"size":>6} | {"LWRR ours/paper":>18} | {"Capybara ours/paper":>21} | ideal Gbps')
for j, s in enumerate(SIZES):
    u = OURS['Uniform'][j]
    lo = 100 * OURS['LWRR'][j] / u if u else 0
    co = 100 * OURS['Capybara'][j] / u if u else 0
    lp = 100 * PAPER['LWRR'][j] / PAPER['Uniform'][j]
    cp = 100 * PAPER['Capybara'][j] / PAPER['Uniform'][j]
    print(f'{s:>6} | {lo:7.0f}% / {lp:5.0f}%      | {co:8.0f}% / {cp:6.0f}%        |'
          f' {u:6.1f} (paper {PAPER["Uniform"][j]:.1f})')
print('wrote fig10_reproduction.png/pdf')
