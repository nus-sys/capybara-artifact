#!/usr/bin/env python3
"""Generate per-server LOADSHIFTS spec for fig10.
usage: gen_spec.py <zipf|uniform> <total_rps_per_client> <runtime_s>
12 '/'-separated segments, one per backend, 'rps:duration_us'."""
import sys

ZIPF12 = [0.3883967083491887, 0.16905948661787334, 0.10392739341425353,
          0.07358741565287161, 0.0563004071301698, 0.04523702543933815,
          0.03759740690089057, 0.0320307830740567, 0.027808946033009267,
          0.02450617557048522, 0.021857692828834718, 0.019690558989028467]

mode, total, runtime = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
dur = runtime * 1000000
if mode == 'zipf':
    weights = ZIPF12
elif mode == 'conn_zipf':
    # The paper skews the 720 CONNECTIONS by Zipf-1.2 and lets the load balancer
    # spread them over the servers, so a server's share is the sum of the weights
    # of the connections it happens to own (round robin over 12 groups).
    NCONN = 12 * 60
    w = [1.0 / (k ** 1.2) for k in range(1, NCONN + 1)]
    tot = sum(w)
    weights = [sum(w[i] for i in range(g, NCONN, 12)) / tot for g in range(12)]
elif mode.startswith('top'):      # spread load evenly over the first N server groups
    n = int(mode[3:])
    weights = [1.0 / n if g < n else 0.0 for g in range(12)]
elif mode == 'solo':          # all load on server group 0 (per-server capacity probe)
    weights = [1.0] + [0.0] * 11
else:
    weights = [1.0 / 12] * 12
print('/'.join(f'{max(int(total * w), 1)}:{dur}' for w in weights))
