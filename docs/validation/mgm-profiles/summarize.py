#!/usr/bin/env python3
"""Summarize the preserved raw timing samples; no extrapolation or speed claim."""
import json
from pathlib import Path
from statistics import median
from collections import defaultdict
base = Path(__file__).parent
samples = defaultdict(list)
for line in base.joinpath('benchmark.jsonl').read_text().splitlines():
    r=json.loads(line)
    samples[(r['kind'],r['length'],r['iterations'])].append(r['ns'])
result=[]
for (kind,length,count), ns in samples.items():
    assert len(ns)==7
    result.append(dict(kind=kind,length=length,iterations=count,samples=7,
                       median_ns=median(ns),ns_per_message=median(ns)/count,
                       mib_per_second=length*count*1e9/median(ns)/1048576))
base.joinpath('benchmark-summary.json').write_text(json.dumps(result,indent=2)+'\n')
print(f'{len(result)} configurations, {sum(len(ns) for ns in samples.values())} raw samples')
