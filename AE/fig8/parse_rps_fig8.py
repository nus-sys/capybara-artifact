#!/usr/bin/env python3
"""Extract per-signal RPS lines from fig8 server logs.
.be{i} lines: "<ns>,RPS_SIGNAL,<sum>,<individual>"  ->  .be{i}_pps_signal: "<ns>,<sum>,<individual>"
(matches the 2024 .be0_pps_signal format the paper's plot reads; values = counts per 1ms window = K rps)
"""
import sys, os

ID = sys.argv[1]
D = os.path.expanduser('~/capybara-data')
for i in (0, 1):
    src = f'{D}/{ID}.be{i}'
    out_lines = []
    with open(src, errors='replace') as f:
        for line in f:
            cols = line.strip().split(',')
            if len(cols) == 4 and cols[1] == 'RPS_SIGNAL':
                out_lines.append(f'{cols[0]},{cols[2]},{cols[3]}')
    with open(f'{D}/{ID}.be{i}_pps_signal', 'w') as f:
        f.write('\n'.join(out_lines) + ('\n' if out_lines else ''))
    print(f'be{i}: {len(out_lines)} signal samples')
