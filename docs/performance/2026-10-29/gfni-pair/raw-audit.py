#!/usr/bin/env python3
import pathlib,json,collections,sys
p=pathlib.Path(sys.argv[1]);total=0;files=[]
for folder in ['logs','final','retained','controls']:
 for f in sorted((p/folder).glob('*.jsonl')):
  rows=[json.loads(s) for s in f.read_text().splitlines()]
  assert rows and all('kind' in r and r['before']>0 and r['after']>0 for r in rows),f
  d=collections.defaultdict(list)
  for r in rows:d[(r['kind'],r['n'],r['inverse'])].append(r['pair'])
  expected=21 if folder in ['final','retained'] and not f.name.startswith('portable') else 11 if folder=='logs' or f.name.startswith('portable') else 21 if f.name.startswith('fixed') else 15
  assert all(v==list(range(expected)) for v in d.values()),f
  total+=len(rows);files.append({'file':str(f.relative_to(p)),'rows':len(rows),'pairs_per_case':expected})
assert len(files)==38 and total==33768,(len(files),total)
print(json.dumps({'timing_files':len(files),'matched_measurement_pairs':total,'files':files},indent=2))
