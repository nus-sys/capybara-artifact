#!/usr/bin/env python3
"""Fig 12 (connection_scalability) — all three curves from this testbed, in the
paper's own style. Reads:
  results_fig12.txt          RES fig12 demikernel-full conn=<N> total_rps=<R>   (curve 1)
  results_fig12_curve2.txt   RES fig12 curve2 conn=<N> mign=<M> total_rps=<R>   (curve 2, Capybara-Switch)
  results_fig12_curve3.txt   RES fig12 curve3 conn=<N> mign=<M> total_rps=<R>   (curve 3, Capybara)
Rendered with the paper's create_plots.py setup() so fonts/colors match Fig 12.
usage: plot_fig12_3curve.py <fig12_dir> <out_basename>
"""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
for _lib in (os.path.join(os.path.dirname(HERE), 'pyenv-lib'),
             '/homes/sigcomm26ae/capybara-AE-runs/pyenv-lib'):
    if os.path.isdir(_lib):
        sys.path.insert(1, _lib); break
sys.path.insert(0, os.path.join(os.path.dirname(HERE),"paperplot"))

D, OUT = sys.argv[1], sys.argv[2]

def load(path, label):
    pts = {}
    if not os.path.exists(path):
        return pts
    for line in open(path):
        m = re.search(rf'{label}.*conn=(\d+).*total_rps=(\d+)', line)
        if m:
            pts[int(m.group(1))] = float(m.group(2))
    return pts

c1 = load(f'{D}/results_fig12.txt', 'demikernel-full')
c2 = load(f'{D}/results_fig12_curve2.txt', 'curve2')
c3 = load(f'{D}/results_fig12_curve3.txt', 'curve3')

import create_plots as cp
cp.setup()
from matplotlib import pyplot as plt
import matplotlib.ticker as tick

fig = plt.figure(figsize=(cp.DEFAULT_WIDTH, 2.3))
ax = fig.add_subplot()

def xy(d):
    xs = sorted(d)
    return xs, [d[x] for x in xs]

if c1:
    x, y = xy(c1); ax.plot(x, y, color='blue', marker='X', markersize=9,
                           label='Demikernel', linestyle='-', linewidth=3)
if c2:
    x, y = xy(c2); ax.plot(x, y, color='red', marker='o', markersize=6,
                           label=f'{cp.SYS}-Switch', linestyle=(0, (8, 2)), linewidth=2)
if c3:
    x, y = xy(c3); ax.plot(x, y, color='green', marker='^', markersize=6,
                           label=f'{cp.SYS}', linestyle='-.', linewidth=1)

ax.set_xlabel('Number of Connections')
ax.set_ylabel('Throughput (reqs/s)')
ax.grid(True, which='both', linestyle='--', alpha=0.4)
ax.legend(loc='best')
ax.set_xscale('log')
ax.set_xticks([100, 1000, 10000, 100000, 200000])
ax.set_xticklabels(["100", "1K", "10K", "100K", "200K"])
ax.set_xlim(100, 300000)
ax.set_ylim(1, 2700000)
ax.yaxis.set_major_formatter(tick.FuncFormatter(cp.millions))
plt.tight_layout()
fig.savefig(OUT + '.pdf', bbox_inches='tight')
fig.savefig(OUT + '.png', dpi=140, bbox_inches='tight')

print('=== Fig-12 three curves (reqs/s, this testbed) ===')
print(f'{"conns":>8} {"Demikernel":>11} {"Capy-Switch":>12} {"Capybara":>10}')
for n in sorted(set(c1) | set(c2) | set(c3)):
    print(f'{n:>8} {c1.get(n,0):>11.0f} {c2.get(n,0):>12.0f} {c3.get(n,0):>10.0f}')
print('wrote', OUT + '.png/.pdf')
