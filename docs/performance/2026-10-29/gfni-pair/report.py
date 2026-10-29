#!/usr/bin/env python3
import pathlib,json,collections,statistics,sys,gzip
p=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else '/home/t3/.cache/kuz-gfni-pair/download')
reports=[]
for f in sorted(p.rglob('*.jsonl')):
 if not (f.name.startswith(('bench-','reverse-','control-','portable-','narrow-','inside-','wide-control-','switch-','wide-switch-','fixed-switch-'))):continue
 groups=collections.defaultdict(list)
 for line in f.read_text().splitlines():
  r=json.loads(line)
  if not 'kind' in r:continue
  if f.name.startswith(('reverse-','inside-reverse-','switch-reverse-','wide-switch-reverse-','fixed-switch-reverse-')):r['before'],r['after']=r['after'],r['before']
  groups[(r['kind'],r['n'],r['inverse'])].append(r)
 for (kind,n,inverse),rows in groups.items():
  ratios=[r['after']/r['before'] for r in rows]
  expected=range(len(rows));assert [r['pair'] for r in rows]==list(expected),(f,kind,n,inverse)
  factor=rows[0]['reps']*rows[0]['jobs']*n
  reports.append(dict(file=str(f.relative_to(p)),reference=('mixed-256' if f.name.startswith('wide-control-') else 'v0.9.3'),kind=kind,n=n,inverse=inverse,samples=len(rows),ratio=statistics.median(ratios),p10=sorted(ratios)[len(ratios)//10],p90=sorted(ratios)[len(ratios)*9//10],before_ns_per_block=statistics.median(r['before']/factor for r in rows),after_ns_per_block=statistics.median(r['after']/factor for r in rows)))
out=pathlib.Path(__file__).resolve().parent
(out/'summary.json.gz').write_bytes(gzip.compress((json.dumps(reports,indent=2)+'\n').encode(),mtime=0))
groups=collections.defaultdict(list)
for r in reports:
 f=r['file']
 category='broad-YMM' if f.startswith('retained/') else 'switch-pilot' if f.startswith('controls/switch-') else 'fixed-switch' if f.startswith('controls/fixed-switch-') else 'wide-switch' if f.startswith('controls/wide-switch-') else 'unchanged' if f.startswith('final/control-') else 'portable' if f.startswith('final/portable-') else None
 if category:groups[(category,r['kind'],r['n'],r['inverse'])].append(r)
aggregates=[]
for (category,kind,n,inverse),rows in groups.items():
 ratios=[r['ratio'] for r in rows]
 aggregates.append(dict(category=category,kind=kind,n=n,inverse=inverse,runs=len(rows),median_paired_ratio=statistics.median(ratios),run_median_range=[min(ratios),max(ratios)],baseline_ns_per_block=statistics.median(r['before_ns_per_block'] for r in rows),candidate_ns_per_block=statistics.median(r['after_ns_per_block'] for r in rows)))
(out/'results.json.gz').write_bytes(gzip.compress((json.dumps(aggregates,indent=2)+'\n').encode(),mtime=0))
print(f'Wrote {len(reports)} per-case and {len(aggregates)} aggregate paired summaries.')
