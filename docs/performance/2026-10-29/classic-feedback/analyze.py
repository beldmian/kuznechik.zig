#!/usr/bin/env python3
"""Summarize raw pairs; ratios are elapsed after / elapsed v0.8.0 (lower wins)."""
import collections
import json
from pathlib import Path
import statistics

HERE = Path(__file__).resolve().parent
runs = {}
for path in sorted([*HERE.glob('retained-*.jsonl'), *HERE.glob('reversed-*.jsonl')]):
    target = 'portable' if 'portable' in path.name else 'native'
    reverse = path.name.startswith('reversed-')
    rows = []
    for line in path.read_text().splitlines():
        r = json.loads(line)
        old, new = (r['after'], r['before']) if reverse else (r['before'], r['after'])
        r['target'] = target
        r['median_ratio'] = statistics.median(n / o for o, n in zip(old, new))
        r['old_ns_per_op'] = statistics.median(old) / r['reps']
        r['new_ns_per_op'] = statistics.median(new) / r['reps']
        rows.append(r)
    assert len(rows) == 136, (path, len(rows)) # 8 widths * 8 cases * 2 modes + 8 CMAC
    runs[path.name] = rows
cells = collections.defaultdict(list)
for filename, rows in runs.items():
    for r in rows:
        key = (r['target'], r['mode'], r['m'], r['bytes'], r['split1'])
        cells[key].append((filename, r))
summary = []
for key, values in sorted(cells.items()):
    target, mode, width, length, split = key
    assert len(values) == 3, (key, len(values))
    ratios = [r['median_ratio'] for _, r in values]
    summary.append(dict(target=target, mode=mode, m=width, bytes=length, split1=split,
                        median_ratio=statistics.median(ratios),
                        min_run_ratio=min(ratios), max_run_ratio=max(ratios),
                        old_ns_per_op=statistics.median(r['old_ns_per_op'] for _, r in values),
                        new_ns_per_op=statistics.median(r['new_ns_per_op'] for _, r in values),
                        runs={name: r['median_ratio'] for name, r in values}))
(HERE / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print(f'{len(runs)} runs; {sum(map(len, runs.values()))} cells; 7 measured + 2 warmup pairs/cell')
for target in ('native', 'portable'):
    for mode in ('CFB-encrypt', 'OFB-xor', 'CMAC'):
        for width in ([1, 2, 3, 16, 64, 65] if mode != 'CMAC' else [1]):
            rows = [r for r in summary if r['target'] == target and r['mode'] == mode and r['m'] == width]
            long = [r for r in rows if r['bytes'] >= 1024]
            print(target, mode, width, '1/16KiB ratios', ', '.join(f'{r["median_ratio"]:.3f}' for r in long))
print('Cells with cross-run median ratio > 1.05:')
for r in summary:
    if r['median_ratio'] > 1.05:
        print(r)
print('Single-run ratios > 1.05:')
for r in summary:
    if r['max_run_ratio'] > 1.05:
        print(r['target'], r['mode'], r['m'], r['bytes'], r['split1'], r['runs'])
