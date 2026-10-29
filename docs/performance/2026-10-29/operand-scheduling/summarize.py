#!/usr/bin/env python3
import json,pathlib,statistics,sys
root=pathlib.Path(sys.argv[1]);out={}
for path in sorted(root.glob('*.jsonl')):
 rows=[]
 for line in path.read_text().splitlines():
  r=json.loads(line)
  if r.get('type')!='result':continue
  ratios=[b/a for a,b in zip(r['before'],r['after'])]
  if path.name.startswith('reverse'):ratios=[1/x for x in ratios]
  ratios.sort();n=len(ratios)
  before='after' if path.name.startswith('reverse') else 'before';after='before' if path.name.startswith('reverse') else 'after'
  rows.append(dict(operation=r['operation'],length=r['length'],pairs=n,ratio=statistics.median(ratios),p10=ratios[n//10],p90=ratios[n*9//10],faster=sum(x<1 for x in ratios),baseline_ns_block=statistics.median(r[before])/(r['reps']*r['length']),candidate_ns_block=statistics.median(r[after])/(r['reps']*r['length']),checksum=r['checksum']))
 if rows:out[path.name]=rows
(root/'summary.json').write_text(json.dumps(out,indent=2)+'\n')
for name,rows in out.items():
 print(name)
 for op in ['encrypt','decrypt']:
  affected=[r for r in rows if r['operation']==op and r['length']>24]
  controls=[r for r in rows if r['operation']==op and r['length']<=24]
  print(op,'affected median',round(statistics.median(r['ratio'] for r in affected),5),'range',tuple(round(f(r['ratio'] for r in affected),5) for f in [min,max]),'controls',tuple(round(f(r['ratio'] for r in controls),5) for f in [min,max]) if controls else None)
