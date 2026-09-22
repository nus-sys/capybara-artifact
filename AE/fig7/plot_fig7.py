#!/usr/bin/env python3
"""Fig-7 reproduction plot. usage: plot_fig7.py <results.txt> <out-basename>

Paper layout: (a) All Flows / (b) Short Flows p99 across workload skews.
Bars = median of repeats (robust to the documented bimodal runs), dots = every run,
triangles = the paper's reported means for reference.
LWRR runs @1.8M pps, Capybara @1.35M pps — each at its calibrated operating point
(current client nodes have a lower per-connection ceiling than the paper testbed).
"""
import re, sys, statistics as st
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

PAPER_ALL_B = [21.2, 2469.7, 5694.9, 7136.8]
PAPER_ALL_C = [23.9, 36.8, 38.2, 105.0]
PAPER_SH_B = [18.0, 18.7, 18.4, 17.1]
PAPER_SH_C = [19.9, 19.9, 19.9, 18.1]

def load(path, tag):
    allf, short = {}, {}
    for line in open(path):
        m = re.match(rf'{tag},([\d.]+),(\w+),FLEET=\d+,\[RESULT\]\s*([\d.,\s]+),SHORT_99=(\d*)',
                     line.strip())
        if not m:
            continue
        z, _, fields, s99 = m.groups()
        v = [x.strip() for x in fields.split(',') if x.strip()]
        allf.setdefault(z, []).append(float(v[6]))
        if s99:
            short.setdefault(z, []).append(float(s99))
    return allf, short

res_path, out = sys.argv[1], sys.argv[2]
ba, bs = load(res_path, 'LWRR')
ca, cs = load(res_path, 'CAPY')
zs = ['0', '0.9', '1.0', '1.2']
labels = ['Uniform', 'Zipf-0.9', 'Zipf-1.0', 'Zipf-1.2']
missing = [z for z in zs if z not in ba or z not in ca]
if missing:
    sys.exit(f'missing data for zipf={missing} — sweep incomplete?')

x = np.arange(4)
w = 0.35
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(9.5, 3.4))

bmed = [st.median(ba[z]) for z in zs]
cmed = [st.median(ca[z]) for z in zs]
ax1.bar(x - w/2, bmed, w, color='lightgrey', hatch='//', edgecolor='k', label='LWRR (ours, median)')
ax1.bar(x + w/2, cmed, w, color='lightblue', hatch='\\\\', edgecolor='k', label='Capybara (ours, median)')
for i, z in enumerate(zs):
    ax1.plot([i - w/2] * len(ba[z]), ba[z], 'o', color='dimgrey', ms=2.5, alpha=0.55)
    ax1.plot([i + w/2] * len(ca[z]), ca[z], 'o', color='navy', ms=2.5, alpha=0.55)
ax1.plot(x - w/2, PAPER_ALL_B, 'v', color='red', ms=7, label='LWRR (paper mean)')
ax1.plot(x + w/2, PAPER_ALL_C, '^', color='darkblue', ms=7, label='Capybara (paper mean)')
ax1.set_yscale('log'); ax1.set_ylim(8, 4e4)
ax1.set_ylabel('p99 Latency (µs)')
ax1.set_xticks(x); ax1.set_xticklabels(labels, fontsize=9)
ax1.set_title('(a) All Flows')
ax1.legend(fontsize=6.5, loc='upper left')
ax1.yaxis.grid(True, which='both', linestyle='--', alpha=0.4); ax1.set_axisbelow(True)

bsm = [st.median(bs[z]) for z in zs]
csm = [st.median(cs[z]) for z in zs]
ax2.bar(x - w/2, bsm, w, color='lightgrey', hatch='//', edgecolor='k')
ax2.bar(x + w/2, csm, w, color='lightblue', hatch='\\\\', edgecolor='k')
ax2.plot(x - w/2, PAPER_SH_B, 'v', color='red', ms=7)
ax2.plot(x + w/2, PAPER_SH_C, '^', color='darkblue', ms=7)
ax2.set_yscale('log'); ax2.set_ylim(8, 4e4)
ax2.set_xticks(x); ax2.set_xticklabels(labels, fontsize=9)
ax2.set_title('(b) Short Flows')
ax2.yaxis.grid(True, which='both', linestyle='--', alpha=0.4); ax2.set_axisbelow(True)

fig.suptitle('Fig. 7 reproduction — LWRR @1.8M pps, Capybara @1.35M pps (each at its calibrated operating point)',
             fontsize=8.5, y=1.00)
fig.tight_layout()
fig.savefig(out + '.pdf')
fig.savefig(out + '.png', dpi=140)

print('\n=== Fig-7 reproduction summary (all-flows p99, median [n runs]) ===')
for z, l in zip(zs, labels):
    r = st.median(ba[z]) / max(st.median(ca[z]), 1e-9)
    print(f'{l:9s}: LWRR {st.median(ba[z]):7.0f} us [{len(ba[z])}]   '
          f'Capybara {st.median(ca[z]):5.0f} us [{len(ca[z])}]   ratio {r:5.0f}x')
print(f'shorts   : LWRR {[f"{v:.0f}" for v in bsm]}  Capybara {[f"{v:.0f}" for v in csm]}')
print(f'wrote {out}.png / {out}.pdf')
