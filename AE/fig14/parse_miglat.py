#!/usr/bin/env python3
"""Turn the servers' time logs into per-migration phase timings.

Each backend writes a timestamped line as a migration passes through it. Ordering
the events of one connection gives the seven intervals the figure is drawn from:

    INIT_MIG -> SEND_PREPARE_MIG          origin CPU
    SEND_PREPARE_MIG -> RECV_PREPARE_MIG          network
    RECV_PREPARE_MIG -> SEND_PREPARE_MIG_ACK      target CPU
    SEND_PREPARE_MIG_ACK -> RECV_PREPARE_MIG_ACK  network
    RECV_PREPARE_MIG_ACK -> SEND_STATE     origin CPU
    SEND_STATE -> RECV_STATE                      network
    RECV_STATE -> CONN_ACCEPTED                   target CPU

Output matches what the paper's plotting code reads: one row per migration of
seven intervals, the total, and the blackout (RECV_PREPARE_MIG_ACK to
CONN_ACCEPTED), all in nanoseconds, plus an avg/min/max/stddev summary.

usage: parse_miglat.py <experiment_id> [data_dir]
"""
import os, statistics, sys

STEPS = ['INIT_MIG', 'SEND_PREPARE_MIG', 'RECV_PREPARE_MIG', 'SEND_PREPARE_MIG_ACK',
         'RECV_PREPARE_MIG_ACK', 'SEND_STATE', 'RECV_STATE', 'CONN_ACCEPTED']
INDEX = {s: i for i, s in enumerate(STEPS)}
WARMUP_FRAC = 0.1     # fraction of migrations to drop while the run settles
WARMUP_MAX = 200      # but never more than this
KEEP = 2000           # most recent migrations to summarise


def read_events(path):
    """Timestamped events after the dump header, as (ns, step, connection)."""
    out = []
    dumping = False
    with open(path) as f:
        for line in f:
            if 'dumping time log data' in line:
                dumping = True
                continue
            if not dumping:
                continue
            c = line.strip().split(',')
            if len(c) < 3 or c[1] not in INDEX:
                continue
            try:
                out.append((int(c[0]), c[1], c[2]))
            except ValueError:
                continue
    return out


def migrations(events):
    """Walk each connection's events and yield one row per completed migration.

    A migration that interleaves with another or loses an event is dropped rather
    than resynchronised, so a partial sequence never contributes a bogus interval.
    """
    by_conn = {}
    for ns, step, conn in events:
        by_conn.setdefault(conn, []).append((ns, step))

    for conn, evs in by_conn.items():
        evs.sort()
        expect, init_ns, prev_ns, blackout_start, row = 0, 0, 0, 0, []
        for ns, step in evs:
            i = INDEX[step]
            if i != expect:
                expect, row = (1, [ns]) if i == 0 else (0, [])
                if i == 0:
                    init_ns, prev_ns = ns, ns
                continue
            if i == 0:
                init_ns, prev_ns, row = ns, ns, []
            else:
                row.append(ns - prev_ns)
                prev_ns = ns
            if step == 'RECV_PREPARE_MIG_ACK':
                blackout_start = ns
            if i == len(STEPS) - 1:
                yield row + [ns - init_ns, ns - blackout_start]
                expect, row = 0, []
                continue
            expect = i + 1


def main():
    eid = sys.argv[1]
    d = sys.argv[2] if len(sys.argv) > 2 else os.environ.get(
        'CAPYBARA_DATA', os.path.expanduser('~/capybara-data'))

    events = []
    for be in ('be0', 'be1'):
        p = f'{d}/{eid}.{be}'
        if os.path.exists(p):
            events += read_events(p)
    if not events:
        sys.exit(f'no time-log events in {d}/{eid}.be*')

    # Each server flushes its time log twice as it shuts down, so the same event
    # arrives more than once. Timestamps are nanosecond-resolution, which makes the
    # triple unique per real event.
    events = sorted(set(events))

    rows = list(migrations(events))
    total = len(rows)
    warmup = min(WARMUP_MAX, int(total * WARMUP_FRAC))
    rows = rows[warmup:][-KEEP:]
    if not rows:
        sys.exit(f'no complete migrations in {eid} ({total} found)')

    with open(f'{d}/{eid}.mig_delay', 'w') as f:
        f.write('\n'.join(','.join(str(v) for v in r) for r in rows) + '\n')

    cols = list(zip(*rows))
    summary = [
        [int(statistics.fmean(c)) for c in cols],
        [min(c) for c in cols],
        [max(c) for c in cols],
        [int(statistics.pstdev(c)) for c in cols],
    ]
    with open(f'{d}/{eid}.mig_delay_avg_minmax_stddev', 'w') as f:
        f.write('\n'.join(','.join(str(v) for v in r) for r in summary) + '\n')

    avg = summary[0]
    origin = (avg[0] + avg[4]) / 1000
    target = (avg[2] + avg[6]) / 1000
    network = (avg[1] + avg[3] + avg[5]) / 1000
    print(f'{eid}: {len(rows)} migrations')
    print(f'  origin CPU {origin:6.2f} us   target CPU {target:6.2f} us   network {network:6.2f} us')
    print(f'  server CPU {origin + target:6.2f} us   total {avg[7]/1000:6.2f} us '
          f'  blackout {avg[8]/1000:6.2f} us')


if __name__ == '__main__':
    main()
