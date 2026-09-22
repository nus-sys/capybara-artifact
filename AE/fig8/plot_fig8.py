#!/usr/bin/env python3
"""Fig-8 reproduction plot (step-function workload, 2 servers).
usage: plot_fig8.py <ID_LWRR> <ID_REACT> <ID_CAPY> <out-basename>
Top row: per-server + total offered workload; bottom row: p99 latency (log), 120ms step window.
"""
import sys, os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as tick
import numpy as np

D = os.path.expanduser('~/capybara-data')
ids = sys.argv[1:4]
out = sys.argv[4]
titles = ['LWRR', 'Capybara-Reactive', 'Capybara']

fig, axes = plt.subplots(2, 3, figsize=(13, 5), sharex=True)

def thousands(x, pos):
    return f'{int(x/1000)}K'

for i, (eid, title) in enumerate(zip(ids, titles)):
    def load_csv(path, ncol):
        rows = []
        for line in open(path):
            p = line.strip().split(',')
            if len(p) >= ncol:
                try:
                    rows.append([float(x) for x in p[:ncol]])
                except ValueError:
                    pass
        return [np.array(c) for c in zip(*rows)] if rows else [np.array([])] * ncol

    sig_t, sig_sum, sig_ind = load_csv(f'{D}/{eid}.be0_pps_signal', 3)
    _, uidx = np.unique(sig_t, return_index=True)
    sig_t, sig_sum, sig_ind = sig_t[uidx], sig_sum[uidx], sig_ind[uidx]
    sched_ms, sched_req = load_csv(f'{D}/{eid}.sched_ms_req', 2)
    lat_ms, lat_avg, lat_p99 = load_csv(f'{D}/{eid}.server_ms_avg_99p_lat', 3)

    # align signal timeline: first sample where be0 individual jumps above 180 (=start of the
    # 270K step, 30ms into the 120ms window)
    jump = np.nonzero(sig_ind > 180)[0]
    t_jump = sig_t[jump[0]] if len(jump) else sig_t[0]
    x_sig = (sig_t - t_jump) / 1e9 + 0.030

    m = (x_sig >= -0.005) & (x_sig <= 0.125)
    x_sig, sig_ind, sig_sum = x_sig[m], sig_ind[m], sig_sum[m]
    axes[0][i].plot(x_sig, sig_ind * 1000, color='blue', marker='o', mfc='none', ms=6,
                    mec='blue', lw=2.5, alpha=0.8, label='Server 0', markevery=0.1)
    axes[0][i].plot(x_sig, (sig_sum - sig_ind) * 1000, color='xkcd:brick red', marker='^',
                    mfc='none', ms=6, mec='xkcd:brick red', lw=2.5, alpha=0.8, label='Server 1',
                    markevery=0.1)
    axes[0][i].plot((sched_ms - 200) / 1000, sched_req * 1000, color='teal', ls='--', lw=2.5,
                    label='Total')
    axes[0][i].set_ylim(0, 1000000)
    axes[0][i].set_xlim(0, 0.12)
    axes[0][i].yaxis.set_major_formatter(tick.FuncFormatter(thousands))
    axes[0][i].set_title(title, fontweight='bold', fontsize=14)

    axes[1][i].plot((lat_ms - 100) / 1000, lat_p99, color='teal', lw=2)
    axes[1][i].set_yscale('log')
    axes[1][i].set_ylim(1, 30000)
    axes[1][i].set_xlabel('Time (s)')

axes[0][0].legend(loc='upper left', ncol=2, fontsize=9)
axes[0][0].set_ylabel('Workload (reqs/s)')
axes[1][0].set_ylabel('p99 Latency (µs)')
fig.tight_layout()
fig.savefig(out + '.pdf')
fig.savefig(out + '.png', dpi=140)
print('wrote', out + '.png')

for eid, title in zip(ids, titles):
    ms, p99 = [], []
    for line in open(f'{D}/{eid}.server_ms_avg_99p_lat'):
        p = line.strip().split(',')
        if len(p) >= 3:
            m, v = float(p[0]) - 100, float(p[2])
            if 0 <= m <= 120:
                ms.append(m); p99.append(v)
    if p99:
        print(f'{title:20s}: window p99 max={max(p99):7.0f}us  median={sorted(p99)[len(p99)//2]:6.0f}us')
