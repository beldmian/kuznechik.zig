#!/usr/bin/env python3
import json, pathlib, statistics as s
root=pathlib.Path(__file__).resolve().parent
allruns={}
for p in sorted(root.glob('*.jsonl')):
    if not ('forward' in p.name or 'reverse' in p.name): continue
    target=p.name.split('-')[0]
    rows=[]
    for line in p.read_text().splitlines():
        r=json.loads(line)
        ratios=[a/b for a,b in zip(r['after'],r['before'])]
        if 'reverse' in p.name: ratios=[1/r for r in ratios]
        key=(target,r['mode'],r['m'],r['bytes'],r['split1'])
        entry=allruns.setdefault(key,[])
        entry.append({'file':p.name,'median':s.median(ratios),'ratios':ratios})
cells=[]
for key,runs in sorted(allruns.items()):
    target,mode,width,n,split=key
    cells.append(dict(target=target,mode=mode,m=width,bytes=n,split=split,median=s.median(r['median'] for r in runs),runs=runs))
(root/'summary.json').write_text(json.dumps(cells,indent=2)+'\n')
lines=[]
for c in cells:
    lines.append(f"{c['target']:8} {c['mode']:11} m{c['m']:3} n{c['bytes']:5} split{int(c['split'])} {c['median']:.6f} runs="+','.join(f"{r['median']:.6f}" for r in c['runs']))
(root/'summary.txt').write_text('\n'.join(lines)+'\n')
for target in sorted(set(c['target'] for c in cells)):
    subset=[c for c in cells if c['target']==target]
    def changed_case(c):
        return c['bytes']>=64 and c['m']>=64 and (c['mode']=='CBC-encrypt' or c['m']&(c['m']-1)==0)
    controls=[c for c in subset if not changed_case(c)]
    changed=[c for c in subset if changed_case(c)]
    print(target,'cells',len(subset),'worst controls',sorted(controls,key=lambda c:c['median'])[-5:])
    print(target,'changed range',min((c['median'] for c in changed),default=0),max((c['median'] for c in changed),default=0))
    print('16KiB',[(c['mode'],c['m'],c['split'],round(c['median'],4)) for c in changed if c['bytes']==16384])
    print('regressions',[(c['mode'],c['m'],c['bytes'],c['split'],round(c['median'],4)) for c in subset if c['median']>1.05])
