#!/usr/bin/env python3
"""Fig-9 reproduction plot: top-10% tail latency CDF, Redis @ ~60% util, Zipf-1.2.
usage: plot_fig9.py <ID_LWRR> <ID_CAPY> <out-basename>
Overlays the paper's original curves (dotted) for reference.
"""
import sys, os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

D = os.path.expanduser('~/capybara-data')
REF = os.path.expanduser('~/capybara-AE-runs/fig9/paper_ref')  # paper's .lat_cdf copies
ids = sys.argv[1:3]
out = sys.argv[3]

def load(path):
    xs, ys = [], []
    for line in open(path):
        p = line.strip().split(',')
        if len(p) >= 2:
            try:
                xs.append(float(p[0])); ys.append(float(p[1]))
            except ValueError:
                pass
    return xs, ys

fig, ax = plt.subplots(figsize=(5.5, 3.2))
for eid, label, style, color in [(ids[0], 'LWRR (ours)', '-', 'tab:gray'),
                                 (ids[1], 'Capybara (ours)', '--', 'tab:blue')]:
    xs, ys = load(f'{D}/{eid}.lat_cdf')
    ax.plot(xs, ys, style, lw=2.5, color=color, label=label)
for f, label, color in [('20240314-031720.063918.lat_cdf', 'LWRR (paper)', 'tab:red'),
                        ('20240314-065502.467400.lat_cdf', 'Capybara (paper)', 'tab:green')]:
    p = f'{REF}/{f}'
    if os.path.exists(p):
        xs, ys = load(p)
        ax.plot(xs, ys, ':', lw=1.8, color=color, alpha=0.8, label=label)

ax.set_ylim(0.9, 1.005)
ax.set_xlim(10, 20000)
ax.set_xscale('log')
ax.set_ylabel('CDF')
ax.set_xlabel('Latency (µs)')
ax.grid(True, which='both', linestyle='--', linewidth=0.5)
ax.legend(loc='lower right', fontsize=8)
fig.tight_layout()
fig.savefig(out + '.pdf')
fig.savefig(out + '.png', dpi=140)

print('=== Fig-9 summary (p99 / p99.9) ===')
for eid, label in [(ids[0], 'LWRR'), (ids[1], 'Capybara')]:
    xs, ys = load(f'{D}/{eid}.lat_cdf')
    def pct(q):
        for x, y in zip(xs, ys):
            if y >= q:
                return x
        return float('nan')
    print(f'{label:10s}: p99={pct(0.99):8.0f}us  p99.9={pct(0.999):8.0f}us')
print('wrote', out + '.png')
