#!/usr/bin/env python3
import json,pathlib,statistics,sys
root=pathlib.Path(sys.argv[1]); output={}
for p in sorted(root.glob('*.jsonl')):
 try: rows=[json.loads(l) for l in p.read_text().splitlines() if l.strip()]
 except (ValueError,UnicodeError):continue
 results=[]
 for r in rows:
  if r.get('type')!='result':continue
  ratios=[b/a for a,b in zip(r['before'],r['after'])]
  if p.name.startswith('reverse-'):ratios=[1/x for x in ratios]
  mid=statistics.median(ratios)
  before,after = (r['after'],r['before']) if p.name.startswith('reverse-') else (r['before'],r['after'])
  results.append(dict(api=r['api'],operation=r['operation'],length=r['length'],pairs=r['pairs'],ratio=mid,p10=sorted(ratios)[len(ratios)//10],p90=sorted(ratios)[len(ratios)*9//10],faster=sum(x<1 for x in ratios),baseline_ns=statistics.median(before)/r['reps']/r['length'],candidate_ns=statistics.median(after)/r['reps']/r['length'],checksum=r['checksum']))
 if results:
  output[p.name]=results
  direct=[f"{r['operation']} {r['ratio']:.6f}" for r in results if r['api']=='block']
  print(p.name,', '.join(direct))
(root/'summary.json').write_text(json.dumps(output,indent=2)+'\n')
