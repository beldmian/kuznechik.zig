#!/usr/bin/env python3
"""Summarize paired time reductions, never independent minima."""
import csv, glob, statistics as st
from pathlib import Path
P = Path(__file__).resolve().parent
all_rows=[]
files=sorted(glob.glob(str(P/'logs/bench-*.csv')))
assert len(files)==18, len(files)
for f in files:
    content=Path(f).read_text().splitlines()
    assert content[-1].startswith('checksum='), f
    assert len(content)==1248, (f,len(content))
    name=Path(f).stem.split('-')
    target,layout=name[1:3]
    for r in csv.DictReader(line for line in Path(f).read_text().splitlines() if not line.startswith('checksum=')):
        r.update(target=target,layout=layout)
        for k in ['seed','payload','aad','pair','iterations','first_ns','second_ns']: r[k]=int(r[k])
        if layout=='reverse': base,cand=r['second_ns'],r['first_ns']
        else: base,cand=r['first_ns'],r['second_ns']
        r.update(reduction=100*(1-cand/base),base_per_call=base/r['iterations'],cand_per_call=cand/r['iterations'])
        all_rows.append(r)
def group(r):
    p,a=r['payload'],r['aad']
    if max(p,a)<=17:return 'tiny (0/1/15/16/17 cross product)'
    if max(p,a)>=1048576:return '1 MiB'
    if p in [64,256,1024,1500,4096,16384] and a in [0,16,17]:return 'records (64 B to 16 KiB)'
    return 'full-block power/batch boundaries'
def med(xs):return st.median(xs)
lines=['Paired wall-time reduction: positive is faster. All warmups excluded.','', '| Target | Workload | Operation | Candidate median % | Control median % |', '|---|---|---|---:|---:|']
for target in ['native','x86_64']:
 for g in dict.fromkeys(group(r) for r in all_rows):
  for op in ['seal','open']:
   subset=[r for r in all_rows if r['target']==target and group(r)==g and r['operation']==op]
   c=[r['reduction'] for r in subset if r['layout']!='control']
   ctrl=[r['reduction'] for r in subset if r['layout']=='control']
   lines.append(f'| {target} | {g} | {op} | {med(c):.2f} | {med(ctrl):.2f} |')
lines+=['','Large cases and aggregate regressions worse than 3% (all cases in case-summary.csv; paired ratios across three seeds, both module layouts):']
keys=sorted(set((r['target'],r['payload'],r['aad'],r['operation']) for r in all_rows))
with (P/'case-summary.csv').open('w') as f:
 writer=csv.writer(f, lineterminator='\n')
 writer.writerow(['target','payload','aad','op','paired_reduction_median_pct','min_seed_layout_median_pct','max_seed_layout_median_pct','control_median_pct','baseline_ns_per_call_median','candidate_ns_per_call_median'])
 for key in keys:
  rows=[r for r in all_rows if (r['target'],r['payload'],r['aad'],r['operation'])==key]
  samples=[r for r in rows if r['layout']!='control']
  strata=[med(r['reduction'] for r in samples if r['seed']==seed and r['layout']==layout) for seed in [7253,9189,20261029] for layout in ['forward','reverse']]
  ctrl=med(r['reduction'] for r in rows if r['layout']=='control')
  values=[med(r['reduction'] for r in samples),min(strata),max(strata),ctrl,med(r['base_per_call'] for r in samples),med(r['cand_per_call'] for r in samples)]
  writer.writerow([*key,*[f'{v:.4f}' for v in values]])
  if values[0]<-3 or max(key[1:3])>=1048576:
   lines.append(f'{key}: median {values[0]:.2f}%, seed/layout range {min(strata):.2f}..{max(strata):.2f}%, control {ctrl:.2f}%')
lines+=['','Individual candidate pair reduction p05/p50/p95, and baseline-v-baseline control:']
for target in ['native','x86_64']:
 for control in [False,True]:
  v=sorted(r['reduction'] for r in all_rows if r['target']==target and (r['layout']=='control')==control)
  lines.append(f'{target} {"control" if control else "candidate"}: n={len(v)}, p05={v[int(.05*(len(v)-1))]:.2f}, median={med(v):.2f}, p95={v[int(.95*(len(v)-1))]:.2f}')
(P/'results.md').write_text('\n'.join(lines)+'\n')
print('\n'.join(lines))
