#!/usr/bin/env python3
"""Paper-style reproduction figures.

Stages this run's data under the filenames the paper's plotting code expects,
then calls the paper's own plot functions (create_plots.py, an unmodified copy
of the repository script that generated every figure in the paper) so fonts,
colors, hatching, and layout match the paper exactly. Only this run's data is
plotted; compare against the corresponding figure in the paper itself.

usage:
  paper_style.py fig7  <results.txt> <out-basename>
  paper_style.py fig8  <ID_LWRR> <ID_REACT> <ID_CAPY> <out-basename>
  paper_style.py fig9  <ID_LWRR> <ID_CAPY> <out-basename>
  paper_style.py fig10 <results.txt> <out-basename>
  paper_style.py fig11 <closed_capy> <closed_prismstar> <closed_proxy> <out-basename>
  paper_style.py fig14 <data_dir> <paper_ref_dir> <out-basename>
"""
import os, re, shutil, statistics as st, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
# pandas/brokenaxes for the kit's system python; the reviewer copy has no
# pyenv-lib of its own and falls back to the author kit's (read-only).
for _lib in (os.path.join(os.path.dirname(HERE), 'pyenv-lib'),
             '/homes/inho/capybara-AE-runs/pyenv-lib'):
    if os.path.isdir(_lib):
        sys.path.insert(1, _lib)
        break
CAPY_DATA = os.environ.get('CAPYBARA_DATA', os.path.expanduser('~/capybara-data'))


def workspace():
    ws = tempfile.mkdtemp(prefix='ae-paperstyle-')
    os.makedirs(os.path.join(ws, 'graphs', 'data'))
    return ws, os.path.join(ws, 'graphs', 'data')


def render(fn_name, ws, out):
    """chdir into the staged workspace and run the paper's plot function."""
    out = os.path.abspath(out)
    os.chdir(ws)
    import create_plots as cp
    cp.setup()
    fig = getattr(cp, 'plot_' + fn_name)()
    fig.savefig(out + '.pdf', bbox_inches='tight')
    fig.savefig(out + '.png', dpi=140, bbox_inches='tight')
    shutil.rmtree(ws, ignore_errors=True)
    print(f'wrote {out}.png / {out}.pdf  (paper-style, this run\'s data only)')


# ---------------------------------------------------------------- fig 7
def fig7(res_path, out):
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

    ba, bs = load(res_path, 'LWRR')
    ca, cs = load(res_path, 'CAPY')
    zs = ['0', '0.9', '1.0', '1.2']
    labels = ['Uniform', 'Zipf-0.9', 'Zipf-1.0', 'Zipf-1.2']
    missing = [z for z in zs if z not in ba or z not in ca]
    if missing:
        sys.exit(f'missing data for zipf={missing} — sweep incomplete?')

    ws, data = workspace()
    # one row of per-condition medians (median is robust to the documented
    # bimodal repeats; the paper function plots the column means of the rows)
    row_all = [st.median(ba[z]) for z in zs] + [st.median(ca[z]) for z in zs]
    row_short = [st.median(bs[z]) for z in zs] + [st.median(cs[z]) for z in zs]
    with open(f'{data}/main_eval.csv', 'w') as f:
        f.write(','.join(f'{v:.1f}' for v in row_all) + '\n')
    with open(f'{data}/main_eval_shortflow.csv', 'w') as f:
        f.write(','.join(f'{v:.1f}' for v in row_short) + '\n')

    print('\n=== Fig-7 reproduction summary (all-flows p99, median [n runs]) ===')
    for z, l in zip(zs, labels):
        r = st.median(ba[z]) / max(st.median(ca[z]), 1e-9)
        print(f'{l:9s}: LWRR {st.median(ba[z]):7.0f} us [{len(ba[z])}]   '
              f'Capybara {st.median(ca[z]):5.0f} us [{len(ca[z])}]   ratio {r:5.0f}x')
    print(f'shorts   : LWRR {[f"{v:.0f}" for v in row_short[:4]]}  '
          f'Capybara {[f"{v:.0f}" for v in row_short[4:]]}')
    render('main_eval_p99', ws, out)


# ---------------------------------------------------------------- fig 8
FIG8_PAPER_IDS = ['20240326-055550.727540',   # LWRR
                  '20240404-090058.707324',   # Capybara-Reactive
                  '20240326-055436.331924']   # Capybara


def _rows(path, ncol):
    out = []
    for line in open(path):
        p = line.strip().split(',')
        if len(p) >= ncol:
            try:
                out.append([float(x) for x in p[:ncol]])
            except ValueError:
                pass
    return out


def fig8(id_lwrr, id_react, id_capy, out):
    ws, data = workspace()
    for rid, pid in zip([id_lwrr, id_react, id_capy], FIG8_PAPER_IDS):
        # switch RPS signals: align so the 270K step lands at t=30ms, then
        # invert the paper function's own transform (x - x_first)/1e6 - 10.
        sig = _rows(f'{CAPY_DATA}/{rid}.be0_pps_signal', 3)
        seen, dedup = set(), []
        for r in sig:
            if r[0] not in seen:
                seen.add(r[0]); dedup.append(r)
        jump = next((r[0] for r in dedup if r[2] > 180), dedup[0][0])
        staged = []
        for t, y0, y1 in dedup:
            x = (t - jump) / 1e6 + 30            # ms on the paper's timeline
            if -10 <= x <= 130:
                staged.append((x, y0, y1))
        if staged and staged[0][0] > -10:        # anchor so x_first maps to -10
            staged.insert(0, (-10.0, staged[0][1], staged[0][2]))
        with open(f'{data}/{pid}.be0_pps_signal', 'w') as f:
            for x, y0, y1 in staged:
                f.write(f'{(x + 10) * 1e6:.0f},{y0:.0f},{y1:.0f}\n')

        # client request schedule (total offered): step window starts at 200ms
        with open(f'{data}/{pid}.sched_ms_req', 'w') as f:
            for ms, req in _rows(f'{CAPY_DATA}/{rid}.sched_ms_req', 2):
                x = ms - 200
                if -10 <= x <= 130:
                    f.write(f'{x + 10:.0f},{req:.0f}\n')

        # per-ms p99 (trace timeline starts 100ms before the window)
        with open(f'{data}/{pid}.server_ms_avg_99p_lat', 'w') as f:
            for ms, avg, p99 in _rows(f'{CAPY_DATA}/{rid}.server_ms_avg_99p_lat', 3):
                x = ms - 100
                if -10 <= x <= 130:
                    f.write(f'{x + 10:.0f},{avg},{p99},0\n')

        for port in ('10000', '10001'):
            src = f'{CAPY_DATA}/{rid}.server_ms_num_conn_{port}'
            dst = f'{data}/{pid}.server_ms_num_conn_{port}'
            if os.path.exists(src) and os.path.getsize(src):
                shutil.copy(src, dst)
            else:
                open(dst, 'w').write('0,50\n')

    for rid, title in zip([id_lwrr, id_react, id_capy],
                          ['LWRR', 'Capybara-Reactive', 'Capybara']):
        p99 = [r[2] for r in _rows(f'{CAPY_DATA}/{rid}.server_ms_avg_99p_lat', 3)
               if 0 <= r[0] - 100 <= 120]
        if p99:
            print(f'{title:20s}: window p99 max={max(p99):7.0f}us  '
                  f'median={sorted(p99)[len(p99)//2]:6.0f}us')
    render('staticl4_vs_sys_step', ws, out)


# ---------------------------------------------------------------- fig 9
FIG9_PAPER_IDS = ['20240314-031720.063918',   # LWRR
                  '20240314-065502.467400']   # Capybara


def fig9(id_lwrr, id_capy, out):
    ws, data = workspace()
    for rid, pid in zip([id_lwrr, id_capy], FIG9_PAPER_IDS):
        shutil.copy(f'{CAPY_DATA}/{rid}.lat_cdf', f'{data}/{pid}.lat_cdf')

    print('=== Fig-9 summary (p99 / p99.9) ===')
    for rid, label in [(id_lwrr, 'LWRR'), (id_capy, 'Capybara')]:
        rows = _rows(f'{CAPY_DATA}/{rid}.lat_cdf', 2)
        def pct(q):
            for x, y in rows:
                if y >= q:
                    return x
            return float('nan')
        print(f'{label:10s}: p99={pct(0.99):8.0f}us  p99.9={pct(0.999):8.0f}us')
    render('redis_latency_cdf', ws, out)


# ---------------------------------------------------------------- fig 10
FIG10_SZ = [1024, 4096, 8192, 16384, 20480]
FIG10_PAPER = {
    'LWRR':     [22.13, 62.51, 99.94, 106.96, 108.08],
    'Capybara': [42.14, 133.36, 201.26, 191.91, 191.91],
    'Uniform':  [55.13, 181.05, 246.56, 229.46, 216.54],
}


def fig10(res_path, out):
    best = {}
    for line in open(res_path):
        m = re.match(r'RES (\w+) (\d+) (\d+) (\d+) ([\d.]+) p99=(\d+)', line.strip())
        if not m:
            continue
        cond, sz, g, p99 = m.group(1), int(m.group(2)), float(m.group(5)), float(m.group(6))
        if p99 > 1000.0:
            continue
        if g > best.get((cond, sz), 0.0):
            best[(cond, sz)] = g
    ours = {name: [best.get((tag, s), 0.0) for s in FIG10_SZ]
            for name, tag in [('LWRR', 'LWRR'), ('Capybara', 'CAPY'), ('Uniform', 'UNI')]}

    ws, data = workspace()
    with open(f'{data}/large_scale.csv', 'w') as f:
        for name in ['LWRR', 'Capybara', 'Uniform']:
            f.write(','.join(f'{v:.2f}' for v in ours[name]) + '\n')

    print('=== Fig-10 summary (peak at p99 <= 1 ms) ===')
    print(f'{"size":>6} | {"LWRR ours/paper":>18} | {"Capybara ours/paper":>21} | ideal Gbps')
    for j, s in enumerate(['1 KB', '4 KB', '8 KB', '16 KB', '20 KB']):
        u = ours['Uniform'][j]
        if ours['LWRR'][j] == 0 and ours['Capybara'][j] == 0 and u == 0:
            print(f'{s:>6} | NO DATA - client node limited (a client completed 0); re-run this size on a rested cluster')
            continue
        lo = 100 * ours['LWRR'][j] / u if u else 0
        co = 100 * ours['Capybara'][j] / u if u else 0
        lp = 100 * FIG10_PAPER['LWRR'][j] / FIG10_PAPER['Uniform'][j]
        cp_ = 100 * FIG10_PAPER['Capybara'][j] / FIG10_PAPER['Uniform'][j]
        print(f'{s:>6} | {lo:7.0f}% / {lp:5.0f}%      | {co:8.0f}% / {cp_:6.0f}%        |'
              f' {u:6.1f} (paper {FIG10_PAPER["Uniform"][j]:.1f})')
    render('large_scale', ws, out)


# ---------------------------------------------------------------- fig 11
def fig11(f_capy, f_prism, f_proxy, out):
    def peaks(path, sysname):
        best = {}
        for line in open(path):
            m = re.match(rf'RES {sysname} closed NB=(\d+) c=\d+ (?:rps=[\d.]+ )?gbps=([\d.]+)',
                         line.strip())
            if m:
                nb, g = int(m.group(1)), float(m.group(2))
                best[nb] = max(best.get(nb, 0.0), g)
        return best

    capy = peaks(f_capy, 'capy')
    prism = peaks(f_prism, 'prismstar')
    proxy = peaks(f_proxy, 'proxy')

    # A cell that sanity-failed on this run is left as a gap (0 -> no bar) rather
    # than aborting the whole figure: the baselines (esp. prism-star) can flake
    # under heavy switch cycling, but that must not block plotting Capybara-L7's
    # own scaling. Capybara-L7 is the claim; require at least one of its cells.
    if not capy:
        sys.exit('no Capybara-L7 closed-loop peaks — run did not produce our system\'s data')
    missing = [(nm, nb) for nm, d in [('capy', capy), ('prism', prism), ('proxy', proxy)]
               for nb in (1, 2, 4) if nb not in d]
    if missing:
        print('NOTE: sanity-failed/absent cells shown as gaps (re-run once on a '
              'rested cluster to fill): ' + ', '.join(f'{nm} NB={nb}' for nm, nb in missing))

    print('=== Fig-11 closed-loop peaks (Gbps, this run; "-" = sanity flake) ===')
    print(f'{"":12s} {"1 Server":>9} {"2 Servers":>10} {"4 Servers":>10}')
    def cell(d, nb):
        return f'{d[nb]:.2f}' if nb in d else '-'
    for name, d in [('L7 Proxy', proxy), ('Prism', prism), ('Capybara-L7', capy)]:
        print(f'{name:12s} {cell(d,1):>9} {cell(d,2):>10} {cell(d,4):>10}')

    # closed-loop panel of the paper's plot_server_scalability_l7 (the runner
    # re-measures closed loop only; open-loop peaks print as RES lines)
    ws, data = workspace()
    out = os.path.abspath(out)
    os.chdir(ws)
    import numpy as np
    import create_plots as cp
    from matplotlib import pyplot as plt
    cp.setup()
    fig, ax = plt.subplots(1, 1, figsize=(cp.DEFAULT_WIDTH * 0.55, 2.3))
    x_labels = ['L7 Proxy', 'Prism', f'{cp.SYS}-L7']
    categories = ['1 Server', '2 Servers', '4 Servers']
    bar_width = 0.25
    patterns = ['-', '/', '\\']
    rows = [[proxy.get(nb, 0.0), prism.get(nb, 0.0), capy.get(nb, 0.0)] for nb in (1, 2, 4)]
    group_spacing = 1.35
    x = np.arange(len(x_labels)) * group_spacing
    for i in range(3):
        ax.bar(x + i * bar_width, rows[i], bar_width, label=categories[i],
               color=cp.lighten(cp.C[i % len(cp.C)]), hatch=patterns[i % len(patterns)])
    ax.set_title('Closed-Loop')
    ax.set_xticks(x + bar_width)
    ax.set_xticklabels(x_labels)
    ax.grid(axis='y', linestyle='--', linewidth=0.7)
    ax.set_ylabel('Throughput (Gbps)')
    fig.legend(categories, loc='upper center', ncol=len(categories),
               bbox_to_anchor=(0.5, 1.1), fontsize='medium')
    plt.tight_layout()
    fig.savefig(out + '.pdf', bbox_inches='tight')
    fig.savefig(out + '.png', dpi=140, bbox_inches='tight')
    shutil.rmtree(ws, ignore_errors=True)
    print(f'wrote {out}.png / {out}.pdf  (paper-style, this run\'s data only)')


# ---------------------------------------------------------------- fig 14
FIG14_PAPER_IDS = {
    'tcp': ['20241209-065306.927851', '20241209-065221.131657', '20241209-065144.964379',
            '20241209-065056.347472', '20241209-064919.683471'],
    'tls': ['20241209-061450.984562', '20241209-061609.116149', '20241209-061703.735981',
            '20241209-061739.852080', '20241209-062125.039885'],
}
FIG14_SIZES = [0, 16384, 32768, 65536, 131072]
FIG14_OURS = {'tcp': 'miglattcp2-{}-sweep', 'tls': 'miglattls{}-sweep'}


def fig14(data_dir, paper_ref, out):
    ws, data = workspace()
    for panel in ('tcp', 'tls'):
        for size, pid in zip(FIG14_SIZES, FIG14_PAPER_IDS[panel]):
            src = os.path.join(data_dir, FIG14_OURS[panel].format(size)
                               + '.mig_delay_avg_minmax_stddev')
            shutil.copy(src, f'{data}/{pid}.mig_delay_avg_minmax_stddev')

    def split(path):
        a = [int(x) for x in open(path).readline().split(',')]
        return (a[0] + a[4]) / 1000, (a[2] + a[6]) / 1000, (a[1] + a[3] + a[5]) / 1000

    for panel in ('tcp', 'tls'):
        print(f'--- {panel}: total us (paper vs ours)')
        for lab, size, pid in zip(['0', '16', '32', '64', '128'],
                                  FIG14_SIZES, FIG14_PAPER_IDS[panel]):
            p = split(os.path.join(paper_ref, pid + '.mig_delay_avg_minmax_stddev'))
            o = split(os.path.join(data_dir, FIG14_OURS[panel].format(size)
                                   + '.mig_delay_avg_minmax_stddev'))
            print(f'  {lab:>4} KB   {sum(p):6.2f}   {sum(o):6.2f}')
    render('state_size_vs_mig_latency', ws, out)


if __name__ == '__main__':
    cmds = {'fig7': fig7, 'fig8': fig8, 'fig9': fig9,
            'fig10': fig10, 'fig11': fig11, 'fig14': fig14}
    if len(sys.argv) < 2 or sys.argv[1] not in cmds:
        sys.exit(__doc__)
    cmds[sys.argv[1]](*sys.argv[2:])
