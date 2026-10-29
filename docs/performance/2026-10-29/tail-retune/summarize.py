#!/usr/bin/env python3
"""Summarize paired elapsed times; raw order is retained in input JSONL."""
import json, math, pathlib, statistics, sys
root = pathlib.Path(sys.argv[1]) if len(sys.argv)>1 else pathlib.Path(__file__).parent
runs = {}
for p in sorted(root.glob('*.jsonl')):
    rows = [json.loads(line) for line in p.read_text().splitlines()]
    cases = []
    for d in rows:
        if d.get('type') != 'result': continue
        r = [b/a for a,b in zip(d['before'], d['after'])]
        assert len(r) >= 9
        cases.append({
            'operation': d['operation'], 'length': d['length'],
            'median_ratio': statistics.median(r),
            'p10': sorted(r)[len(r)//10], 'p90': sorted(r)[len(r)*9//10],
            'median_before_ns_per_call': statistics.median(d['before'])/d['reps'],
            'median_after_ns_per_call': statistics.median(d['after'])/d['reps'],
            'pairs_faster': sum(x<1 for x in r), 'pairs': len(r),
            'checksum': d['checksum'],
        })
    runs[p.name] = {'config':rows[0], 'validation':rows[1], 'cases':cases}
(root / 'summary.json').write_text(json.dumps(runs, indent=2)+'\n')
for name,run in runs.items():
    print(name, len(run['cases']), 'cases')
    for d in sorted(run['cases'], key=lambda d:(d['length'],d['operation'])):
        if d['length'] in (20,21,22,23,24,25,84,85,86,87,88,89):
            print(d['operation'],d['length'],round(d['median_ratio'],4),f"[{d['p10']:.4f}, {d['p90']:.4f}]",f"{d['pairs_faster']}/{d['pairs']}")
