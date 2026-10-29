#!/usr/bin/env python3
"""Paired ratios, per-offset controls and compact confirmation table."""
import json,pathlib,statistics,sys
p=pathlib.Path(sys.argv[1]);summary=json.loads((p/'summary.json').read_text());out={}
for f,rows in summary.items():
 if f.startswith('explore-'):
  assert len(rows)==4,(f,len(rows));continue
 assert len(rows)==84,(f,len(rows))
 raw=[json.loads(l) for l in (p/f).read_text().splitlines()];config=raw[0]
 assert all(r['pairs']==config['pairs'] for r in rows)
 cases=[]
 for r in raw:
  if r.get('type')!='result':continue
  rs=[b/a for a,b in zip(r['before'],r['after'])]
  if f.startswith('reverse-'):rs=[1/x for x in rs]
  offsets={str(((offset+1)%4)*16):statistics.median([x for i,x in enumerate(rs) if (i+3)%4==offset]) for offset in range(4)}
  cases.append(dict(api=r['api'],operation=r['operation'],length=r['length'],offset_ratio_medians=offsets))
 out[f]={'direct':{r['operation']:r for r in rows if r['api']=='block'},'singleton':{r['operation']:r for r in rows if r['api']=='blocks' and r['length']==1},'slice2to24':{op:statistics.median([r['ratio'] for r in rows if r['api']=='blocks' and 2<=r['length']<=24 and r['operation']==op]) for op in ['encrypt','decrypt']},'slice25plus':{op:statistics.median([r['ratio'] for r in rows if r['length']>=25 and r['operation']==op]) for op in ['encrypt','decrypt']},'offset_controls':cases}
(p/'confirmation.json').write_text(json.dumps(out,indent=2)+'\n')
lines=['run | direct encrypt | direct decrypt | singleton encrypt | singleton decrypt | median slices 2..24 enc / dec | median slices >=25 enc / dec','--- | ---: | ---: | ---: | ---: | ---: | ---:']
for f,d in out.items():
 lines.append(f"{f} | {d['direct']['encrypt']['ratio']:.6f} | {d['direct']['decrypt']['ratio']:.6f} | {d['singleton']['encrypt']['ratio']:.6f} | {d['singleton']['decrypt']['ratio']:.6f} | {d['slice2to24']['encrypt']:.6f} / {d['slice2to24']['decrypt']:.6f} | {d['slice25plus']['encrypt']:.6f} / {d['slice25plus']['decrypt']:.6f}")
(p/'confirmation-table.md').write_text('\n'.join(lines)+'\n')
print('\n'.join(lines))
