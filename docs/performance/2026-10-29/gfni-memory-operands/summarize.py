#!/usr/bin/env python3
import json,pathlib,statistics,sys
s=pathlib.Path(sys.argv[1]);out={}
for path in sorted(s.glob('*.jsonl')):
 if not any(path.name.startswith(v+'-') for v in ['candidate','explicit-clobber','explicit-read']):continue
 rows=[json.loads(l) for l in path.read_text().splitlines()]; assert rows[0]['type']=='config' and rows[1]['type']=='validation'; assert rows[1]['passed']
 config=rows[0];portable='-portable-' in path.name
 assert config['zig']=='0.15.1' and config['optimization']=='ReleaseFast'
 assert config['pairs']==(15 if portable else 31) and config['target_blocks']==(131072 if portable else 1048576)
 assert str(config['seed']) in path.name and config['warmup_pairs']==3
 assert rows[1]==dict(type='validation',keys=3,lengths=141,offsets=4,directions=2,guards=True,passed=True)
 cases=[]
 for row in rows[2:]:
  assert row['type']=='result';assert len(row['before'])==len(row['after'])==rows[0]['pairs']
  reverse='-reverse-' in path.name
  ratios=[a/b if reverse else b/a for a,b in zip(row['before'],row['after'])]; assert all(a>0 and b>0 for a,b in zip(row['before'],row['after']))
  rr=sorted(ratios); n=len(rr)
  row.update(median=statistics.median(rr),p10=rr[n//10],p90=rr[n*9//10],faster_pairs=sum(r<1 for r in rr),offset_medians={str((((j+3)%4)+1)*16%64):statistics.median(ratios[j::4]) for j in range(4)},baseline_ns_per_block=statistics.median(row['after'] if reverse else row['before'])/(row['length']*row['reps']),candidate_ns_per_block=statistics.median(row['before'] if reverse else row['after'])/(row['length']*row['reps']))
  cases.append(row)
 assert len(cases)==66,(path,len(cases))
 aggregate={op:statistics.median(r['median'] for r in cases if r['operation']==op and r['length']>24) for op in ['encrypt','decrypt']}
 controls=[r['median'] for r in cases if r['length']<=24]
 out[path.name]=dict(config=rows[0],validation=rows[1],affected=aggregate,control_range=[min(controls),max(controls)],cases=cases)
 print(path.name,aggregate,'controls',min(controls),max(controls))
assert len(out)==12,len(out)
checks={}
for name,d in out.items():
 for c in d['cases']:
  key=(d['config']['seed'],c['operation'],c['length'])
  if key in checks:assert checks[key]==c['checksum'],(name,key)
  checks[key]=c['checksum']
(s/'summary.json').write_text(json.dumps(out,indent=2)+'\n')
