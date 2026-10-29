#!/usr/bin/env python3
import html,json,pathlib,statistics,sys
p=pathlib.Path(sys.argv[1]);d=json.loads((p/'confirmation.json').read_text())
W,H=700,310;left,right=205,680
x=lambda v:left+(v-.99)/.05*(right-left)
svg=[f'<svg viewBox="0 0 {W} {H}" width="100%" height="310" role="img" aria-label="Direct public API paired latency ratios. All candidate confirmations regress both directions.">']
svg+=['<style>text{fill:var(--foreground);font:12px var(--font-sans, sans-serif)}.axis{stroke:var(--border);stroke-width:1}.enc{fill:var(--chart-1)}.dec{fill:var(--chart-2)}</style>']
controls=[v['direct'][op]['ratio'] for name,v in d.items() if name.startswith('confirm-control-') for op in ['encrypt','decrypt']]
lo,hi=min(controls),max(controls)
svg.append(f'<rect x="{x(lo)}" y="25" width="{x(hi)-x(lo)}" height="215" fill="var(--foreground)" opacity=".08"/>')
for v in [.99,1,1.01,1.02,1.03,1.04]:
 xx=x(v);svg.append(f'<path class="axis" d="M{xx} 25V240"/><text x="{xx}" y="260" text-anchor="middle">{v:.2f}</text>')
svg.append(f'<path d="M{x(1)} 20V240" stroke="var(--foreground)" stroke-dasharray="3 3" opacity=".65"/>')
for j,(n,pos) in enumerate([('boundary','0,6,7,8,9'),('split2','0,1,8,9,10'),('spaced','0,3,6,9,12')]):
 yy=62+j*72;svg.append(f'<text x="0" y="{yy}">{n} [{pos}]</text>')
 for k,f in enumerate([f'confirm-{n}-94201.jsonl',f'confirm-{n}-94202.jsonl',f'reverse-{n}-94203.jsonl']):
  for op in ['encrypt','decrypt']:
   v=d[f]['direct'][op]['ratio'];y=yy-5+(k-1)*12;xx=x(v)
   if op=='encrypt':svg.append(f'<circle class="enc" cx="{xx}" cy="{y}" r="4"><title>{n} {op}, {f}: {v:.6f}</title></circle>')
   else:svg.append(f'<path class="dec" d="M{xx} {y-5}l5 5 -5 5 -5 -5Z"><title>{n} {op}, {f}: {v:.6f}</title></path>')
svg.append('<text x="205" y="292">candidate / v0.9.1 elapsed time · lower is faster</text></svg>')
page='''<!doctype html><html><head><meta charset="utf-8"><title>Hybrid position rejection</title><style>
html,body{margin:0;color:var(--foreground);font:14px var(--font-sans,sans-serif)}p{line-height:1.5;margin:8px 0}.legend{display:flex;gap:18px;flex-wrap:wrap}.legend span:first-child{color:var(--chart-1)}.legend span:nth-child(2){color:var(--chart-2)}small{color:var(--muted-foreground)}
</style></head><body><p><strong>Retain positions [0,1,2,3,4].</strong> No finalist improves both direct APIs in any confirmation.</p><div class="legend"><span>encrypt (circles)</span><span>decrypt (diamonds)</span><span>Shaded: baseline-control direct range</span></div>'''+''.join(svg)+'''<p><small>Three points per direction: two seeds, then reversed module placement. Each is the median of 31 paired samples after three warmups; 524,288 calls/sample. Four legal block offsets rotate. Zig 0.15.1 LLVM, native Zen5, Boat Ryzen 9 9950X. Tiny differences within noise are unresolved.</small></p></body></html>'''
(p/'results.html').write_text(page)
