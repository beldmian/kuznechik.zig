#!/usr/bin/env python3
"""Audit each paired raw sample; report complete distributions, never minima."""
import json,pathlib,statistics,sys
s=pathlib.Path(sys.argv[1]);out={};checks={};total=0
widths={1,2,4,8,12,16,20,21,23,24,25,31,32,47,63,64,65,79,87,88,89,95,127,128,129,255,256,257,1024,1025,4096,16384}
for path in sorted(s.glob('*.jsonl')):
 if not path.name.startswith(('explore-','confirm-','reverse-','control-','portable-')):continue
 events=[json.loads(l) for l in path.read_text().splitlines() if l.strip()];config=events[0];validation=events[1]
 assert config['type']=='config' and validation['type']=='validation' and validation['passed']
 results=events[2:];assert len(results)==66,(path,len(results))
 assert {r['length'] for r in results if r['operation']=='encrypt'}==widths,path
 reverse=path.name.startswith('reverse-');cases=[]
 for r in results:
  a,b=r['before'],r['after'];assert len(a)==len(b)==config['pairs'] and all(v>0 for v in a+b)
  ratios=[y/x if not reverse else x/y for x,y in zip(a,b)];ratiosort=sorted(ratios)
  k=(config['seed'],r['operation'],r['length'],r['reps'])
  assert checks.setdefault(k,r['checksum'])==r['checksum'],(path,k)
  rawmedian=statistics.median([y/x for x,y in zip(a,b)])
  assert abs(rawmedian-r['ratio_median'])<1e-8
  offsets={str(o):statistics.median([ratios[j] for j in range(len(a)) if (j+4)%4==o]) for o in range(4) if any((j+4)%4==o for j in range(len(a)))}
  cases.append(dict(operation=r['operation'],length=r['length'],reps=r['reps'],pairs=len(a),median=statistics.median(ratios),p10=ratiosort[len(a)//10],p90=ratiosort[len(a)*9//10],faster_pairs=sum(v<1 for v in ratios),baseline_ns_per_block=statistics.median(b if reverse else a)/(r['reps']*r['length']),candidate_ns_per_block=statistics.median(a if reverse else b)/(r['reps']*r['length']),by_offset_mod4=offsets,checksum=r['checksum']))
  total+=len(a)
 agg={}
 for op in ['encrypt','decrypt']:
  affected=[r['median'] for r in cases if r['operation']==op and r['length']>=25]
  controls=[r['median'] for r in cases if r['operation']==op and r['length']<25]
  agg[op]=dict(affected_median_of_cases=statistics.median(affected),affected_min=min(affected),affected_max=max(affected),affected_cases=len(affected),affected_faster_cases=sum(v<1 for v in affected),small_control_median=statistics.median(controls))
 out[path.name]=dict(config=config,reversed_modules=reverse,aggregate=agg,cases=cases)
 print(path.name,*(f'{op} {v["affected_median_of_cases"]:.6f} range {v["affected_min"]:.6f}..{v["affected_max"]:.6f}' for op,v in agg.items()))
(s/'summary.json').write_text(json.dumps(out,indent=2)+'\n')
(s/'data-audit.json').write_text(json.dumps(dict(files=len(out),cases=sum(len(v['cases']) for v in out.values()),paired_samples=total,complete_output_checksums_across_variants=True,paired_ratio_audit=True),indent=2)+'\n')
