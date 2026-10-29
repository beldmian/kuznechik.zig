#!/usr/bin/env python3
"""Summarize paired ratios; reverse results use candidate/released orientation."""
import json, pathlib, statistics, sys
root=pathlib.Path(sys.argv[1]) if len(sys.argv)>1 else pathlib.Path(__file__).resolve().parent
out={}
for name,reverse in [('pair70-70001',False),('pair69-69001',False),('pair70-70002',False),('reverse70-70003',True),('pair70-70004',False)]:
    p=root/(name+'.jsonl')
    if not p.exists():continue
    rows=[json.loads(line) for line in p.read_text().splitlines()]
    results=[]
    for r in rows:
        if r['type']!='result':continue
        a,b=(r['after'],r['before']) if reverse else (r['before'],r['after'])
        ratios=sorted(y/x for x,y in zip(a,b))
        results.append(dict(operation=r['operation'],length=r['length'],pairs=r['pairs'],reps=r['reps'],ratio_median=statistics.median(ratios),ratio_p10=ratios[len(ratios)//10],ratio_p90=ratios[len(ratios)*9//10],faster_pairs=sum(v<1 for v in ratios),before_ns_per_block=statistics.median(a)/r['reps']/r['length'],after_ns_per_block=statistics.median(b)/r['reps']/r['length'],checksum=r['checksum']))
    out[name]={'config':rows[0],'validation':rows[1],'results':results}
(root/'summary.json').write_text(json.dumps(out,indent=2)+'\n')
