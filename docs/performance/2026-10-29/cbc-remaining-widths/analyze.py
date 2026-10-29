#!/usr/bin/env python3
from pathlib import Path
import collections,gzip,json,statistics as s,tarfile
p=Path(__file__).resolve().parent
retained={1,2,3,4,8,16,24,31,32,63,64,65,128}
new=set(range(4,64))-retained
with tarfile.open(p/'evidence.tar.gz') as t:
 files={m.name:t.extractfile(m).read() for m in t.getmembers() if m.isfile()}
for group in ['final','control','confirmation']:
 D=collections.defaultdict(lambda:collections.defaultdict(list)); rows=0
 for n,d in sorted(files.items()):
  if not n.startswith('evidence/'+group+'/') or not n.endswith('.jsonl'):continue
  for l in d.decode().splitlines():
   r=json.loads(l);rows+=1
   ratios=[a/b for a,b in zip(r['after'],r['before'])]
   if 'reverse' in n:ratios=[1/r for r in ratios]
   key=(Path(n).name.split('-')[0],r['m'],r['bytes'],r['split1'])
   D[key][Path(n).name]+=ratios
 if not rows:continue
 cells=[]
 for (target,w,n,split),runs in sorted(D.items()):
  runs=[dict(file=f,median=s.median(r),ratios=r) for f,r in runs.items()]
  cells.append(dict(target=target,m=w,bytes=n,split=split,median=s.median(r['median'] for r in runs),runs=runs))
 with gzip.GzipFile(p/(group+'-summary.json.gz'),'wb',mtime=0) as f:f.write((json.dumps(cells,indent=2)+'\n').encode())
 out=[f'{group}: {rows} rows / {rows*9} measured pairs; {len(cells)} aggregate cells']
 for target in ['native','baseline']:
  groups={'all':lambda c:True,'existing widths':lambda c:c['m'] in retained,'new width scalar calls':lambda c:c['m'] in new and (c['bytes']<64 or (c['split'] and c['bytes']<80)),'new width batched calls':lambda c:c['m'] in new and c['bytes']>=(80 if c['split'] else 64)}
  for name,pred in groups.items():
   subset=[c for c in cells if c['target']==target and pred(c)]
   if not subset:continue
   worst=max(subset,key=lambda c:c['median'])
   out.append(f"{target} {name}: max {worst['median']:.6f} IV{worst['m']} n{worst['bytes']} split{int(worst['split'])}; runs="+','.join(f"{r['median']:.6f}" for r in worst['runs']))
  out.append('Highest aggregate ratios:')
  for c in sorted([c for c in cells if c['target']==target],key=lambda c:c['median'],reverse=True)[:15]:
   out.append(f"  IV{c['m']} n{c['bytes']} split{int(c['split'])} {c['median']:.6f}; runs="+','.join(f"{r['median']:.6f}" for r in c['runs']))
 (p/(group+'-analysis.txt')).write_text('\n'.join(out)+'\n')
 print('\n'.join(out))
 if group=='final':
  table=['| IV blocks | Native whole | Native split | Portable whole | Portable split |','| ---: | ---: | ---: | ---: | ---: |']
  for w in sorted(new):
   vals=[next(c['median'] for c in cells if c['target']==t and c['m']==w and c['bytes']==16384 and c['split']==sp) for t in ['native','baseline'] for sp in [False,True]]
   table.append('| '+str(w)+' | '+' | '.join(f'{v:.6f}' for v in vals)+' |')
  (p/'large-table.md').write_text('\n'.join(table)+'\n')
