#!/usr/bin/env python3
"""Fig. 14 reproduction — migration latency by connection state size, both panels.

Stacked as the paper stacks it (origin CPU / target CPU / network, from the avg
row of each .mig_delay_avg_minmax_stddev); for every state size the paper's bar
(its own data files) stands beside ours.

usage: plot_fig14.py <data_dir> <paper_ref_dir> <out_basename>
data_dir holds miglattcp2-<bytes>-sweep.* and miglattls<bytes>-sweep.* summaries.
"""
import os, sys
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

D, REF, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
SIZES = [0, 16384, 32768, 65536, 131072]
LABELS = ['0', '16', '32', '64', '128']
PAPER = {
    'tcp': ['20241209-065306.927851', '20241209-065221.131657', '20241209-065144.964379',
            '20241209-065056.347472', '20241209-064919.683471'],
    'tls': ['20241209-061450.984562', '20241209-061609.116149', '20241209-061703.735981',
            '20241209-061739.852080', '20241209-062125.039885'],
}
OURS = {'tcp': 'miglattcp2-{}-sweep', 'tls': 'miglattls{}-sweep'}

def split(path):
    a = [int(x) for x in open(path).readline().split(',')]
    return (a[0] + a[4]) / 1000, (a[2] + a[6]) / 1000, (a[1] + a[3] + a[5]) / 1000

fig, axes = plt.subplots(1, 2, figsize=(9.6, 3.1), sharey=True)
colors = ['firebrick', 'lightcoral', 'forestgreen']
names = ['Origin CPU', 'Target CPU', 'Network Latency']

for ax, panel, title in ((axes[0], 'tcp', '(a) TCP'), (axes[1], 'tls', '(b) TLS')):
    paper = [split(os.path.join(REF, e + '.mig_delay_avg_minmax_stddev')) for e in PAPER[panel]]
    ours = [split(os.path.join(D, OURS[panel].format(s) + '.mig_delay_avg_minmax_stddev'))
            for s in SIZES]
    x = np.arange(len(SIZES)); w = 0.36
    for off, rows, alpha, tag in ((-w/2, paper, 0.5, 'paper'), (w/2, ours, 1.0, 'ours')):
        bottom = np.zeros(len(SIZES))
        for i in range(3):
            vals = [r[i] for r in rows]
            ax.bar(x + off, vals, w, bottom=bottom, color=colors[i], alpha=alpha,
                   edgecolor='k', linewidth=0.5,
                   label=names[i] if (tag == 'ours' and panel == 'tcp') else None)
            bottom += np.array(vals)
        for xi, b in zip(x + off, bottom):
            ax.text(xi, b + 0.8, f'{b:.0f}', ha='center', fontsize=7,
                    color='dimgray' if tag == 'paper' else 'black')
    ax.set_xticks(x); ax.set_xticklabels(LABELS)
    ax.set_xlabel('Additional State Size (KB)')
    ax.set_title(title, fontsize=10)
    ax.grid(axis='y', linestyle='--', linewidth=0.5); ax.set_axisbelow(True)
    print(f'--- {panel}: total us (paper vs ours)')
    for lab, p, o in zip(LABELS, paper, ours):
        print(f'  {lab:>4} KB   {sum(p):6.2f}   {sum(o):6.2f}')

axes[0].set_ylabel('Migration Latency (μs)')
axes[0].legend(fontsize=8, loc='upper left')
fig.suptitle('Fig. 14 reproduction — paper (faded) vs ours, 2,000 migrations per bar',
             fontsize=9, y=1.02)
fig.tight_layout()
fig.savefig(OUT + '.pdf', bbox_inches='tight'); fig.savefig(OUT + '.png', dpi=140, bbox_inches='tight')
print('wrote', OUT + '.png/.pdf')
