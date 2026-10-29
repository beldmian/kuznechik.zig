#!/usr/bin/env python3
import json,pathlib,statistics as s,collections,sys
root=pathlib.Path(sys.argv[1]) if len(sys.argv)>1 else pathlib.Path(__file__).resolve().parent/'final'
D=collections.defaultdict(lambda:collections.defaultdict(list))
for p in sorted(root.glob('*.jsonl')):
 if not any(x in p.name for x in ['forward','reverse']): continue
 for line in p.read_text().splitlines():
  r=json.loads(line)
  rs=[a/b for a,b in zip(r['after'],r['before'])]
  if 'reverse' in p.name: rs=[1/x for x in rs]
  key=(p.name.split('-')[0],r['mode'],r['m'],r['bytes'],r['split1'])
  D[key][p.name]+=rs
cells=[]
for key,runs in sorted(D.items()):
 t,m,w,n,split=key
 runs=[dict(file=p,median=s.median(rs),ratios=rs) for p,rs in runs.items()]
 cells.append(dict(target=t,mode=m,m=w,bytes=n,split=split,median=s.median(x['median'] for x in runs),runs=runs))
(root/'summary.json').write_text(json.dumps(cells,indent=2)+'\n')
(root/'summary.txt').write_text('\n'.join(f"{c['target']:8} {c['mode']:11} IV{c['m']:3} n{c['bytes']:5} split{int(c['split'])} {c['median']:.6f} runs="+','.join(f"{x['median']:.6f}" for x in c['runs']) for c in cells)+'\n')
print('Worst cells:')
for c in sorted(cells,key=lambda x:x['median'],reverse=True)[:18]: print(c['target'],c['mode'],c['m'],c['bytes'],c['split'],round(c['median'],5),[round(x['median'],5) for x in c['runs']])
print('Large whole:')
for c in cells:
 if c['bytes']==16384 and not c['split']:print(c['target'],c['mode'],c['m'],round(c['median'],6),[round(x['median'],6) for x in c['runs']])
