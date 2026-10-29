#!/usr/bin/env python3
import json,pathlib,statistics,sys
p=pathlib.Path(sys.argv[1]);files={};digests={};pairs=0;cases=0
for f in sorted(p.glob('*.jsonl')):
 if not f.name.startswith(('explore-','confirm-','reverse-','portable-')):continue
 rows=[json.loads(l) for l in f.read_text().splitlines() if l.strip()]
 cfg=rows[0];assert cfg['type']=='config' and cfg['warmup_pairs']==3,f
 assert rows[1]['type']=='validation' and rows[1]['passed'],f
 rs=rows[2:];assert len(rs)==(4 if f.name.startswith('explore-') else 84),(f,len(rs))
 for r in rs:
  assert r['type']=='result' and len(r['before'])==len(r['after'])==r['pairs']==cfg['pairs'],f
  assert all(v>0 for v in r['before']+r['after']),f
  ratio=statistics.median([b/a for a,b in zip(r['before'],r['after'])])
  assert abs(ratio-r['ratio_median'])<1e-8,(f,ratio,r['ratio_median'])
  key=(cfg['seed'],r['operation'],r['api'],r['length'],r['pairs'],r['reps'])
  if key in digests:assert digests[key]==r['checksum'],(f,key)
  digests[key]=r['checksum'];pairs+=r['pairs'];cases+=1
 files[f.name]=dict(seed=cfg['seed'],cases=len(rs),pairs_per_case=cfg['pairs'])
assert len(files)==32,len(files)
(p/'data-audit.json').write_text(json.dumps(dict(files=files,result_cases=cases,paired_samples=pairs,same_seed_outputs_identical=True,ratios_recomputed=True),indent=2)+'\n')
print(len(files),cases,pairs,'raw files/cases/paired samples audited')
