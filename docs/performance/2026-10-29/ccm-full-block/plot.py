#!/usr/bin/env python3
import json,pathlib
root=pathlib.Path(__file__).resolve().parent
summary=json.loads((root/'summary.json').read_text())
names=['native-7654321.jsonl','native-99887766.jsonl','reverse-44332211.jsonl']
svg=['<svg viewBox="0 0 680 280" role="img" aria-label="CCM paired median time reduction with p10 to p90 ranges">']
for tick in range(-9,19,3):
 y=165-tick*6
 svg.append(f'<path d="M48 {y}H665" stroke="var(--border,#777)" stroke-dasharray="3 4"/><text x="40" y="{y+4}" text-anchor="end">{tick}%</text>')
for gi,(n,op) in enumerate((n,op) for n in (1024,65536,1048576) for op in ('seal','open')):
 x=95+gi*105
 label={1024:'1 KiB',65536:'64 KiB',1048576:'1 MiB'}[n]
 svg.append(f'<text x="{x}" y="249" text-anchor="middle">{op}</text><text x="{x}" y="267" text-anchor="middle">{label}</text>')
 for i,name in enumerate(names):
  d=next(d for d in summary[name]['cases'] if d['operation']==op and d['length']==n)
  v,lo,hi=d['median_ratio'],d['p10'],d['p90']
  if name.startswith('reverse'):v,lo,hi=1/v,1/hi,1/lo
  gain=(1-v)*100; xx=x+(i-1)*12; color=f'var(--chart-{i+1},currentColor)'
  svg.append(f'<path d="M{xx} {165-(1-lo)*600:.2f}V{165-(1-hi)*600:.2f}" stroke="{color}" opacity=".5"/><circle cx="{xx}" cy="{165-gain*6:.2f}" r="4" fill="{color}"><title>{name}: {gain:.2f}% less time; paired p10–p90 ratio {lo:.4f}–{hi:.4f}</title></circle>')
svg.append('</svg>')
legend=' '.join(f'<span style="color:var(--chart-{i+1},currentColor)">● {name[:-6]}</span>' for i,name in enumerate(names))
html='''<!doctype html><html><head><meta charset="utf-8"><style>
body{margin:0;font:13px var(--font-sans,system-ui);color:var(--foreground,#222)}svg{width:100%;height:280px}text{fill:currentColor;font-size:12px}p{margin:8px 0}.legend{display:flex;flex-wrap:wrap;gap:12px;font-size:11px}
</style></head><body><p><strong>CCM native seal/open: reduction in elapsed time</strong></p>'''+''.join(svg)+'<div class="legend">'+legend+'</div><p>Dots: median paired ratios. Lines: p10–p90. CPU0 · Ryzen9950X guest · Zig0.15.1 ReleaseFast native. Portable paths stayed roughly tied. One guest; the overall speed goal remains unproven.</p></body></html>'
(root/'results.html').write_text(html+'\n')
