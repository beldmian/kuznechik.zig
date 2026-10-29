#!/usr/bin/env python3
from pathlib import Path
import gzip,json
p=Path(__file__).resolve().parent
cells=json.loads(gzip.decompress((p/'final-summary.json.gz').read_bytes()))
new=set(range(4,64))-{4,8,16,24,31,32,63}
svg=['<svg viewBox="0 0 650 190" role="img" aria-label="Whole 16 KiB candidate over v0.9.3 elapsed ratios for every newly batched CBC width; lower is better">']
for tick in [0,.25,.5,.75,1]:
 x=115+tick*485
 svg.append(f'<path d="M{x} 15V140" class="grid"/><text x="{x}" y="164" text-anchor="middle">{tick:g}</text>')
for ti,target in enumerate(['native','baseline']):
 y=48+ti*66; values=sorted([c for c in cells if c['target']==target and c['m'] in new and c['bytes']==16384 and not c['split']],key=lambda c:c['m'])
 color='var(--chart-1)' if ti==0 else 'var(--chart-2)'
 svg.append(f'<text x="0" y="{y+4}">{"Native" if ti==0 else "Portable"}</text>')
 for i,c in enumerate(values):
  x=115+c['median']*485;dy=(i%5-2)*3
  svg.append(f'<circle cx="{x:.2f}" cy="{y+dy}" r="3" fill="{color}" opacity=".7"><title>IV{c["m"]}: {c["median"]:.6f}</title></circle>')
svg.append('<text x="600" y="183" text-anchor="middle">v0.9.3 = 1</text></svg>')
html='''<!doctype html><html><head><meta charset="utf-8"><style>
:root{font-family:var(--font-sans);color:var(--foreground)}body{margin:0}figure{margin:0}svg{width:100%;height:210px}text{fill:var(--foreground);font:13px var(--font-sans)}.grid{stroke:var(--border);stroke-dasharray:3 4}p{font-size:13px;color:var(--muted-foreground);line-height:1.5;margin:8px 0}figcaption{font-size:15px;font-weight:600}
</style></head><body><figure><figcaption>CBC whole 16 KiB — elapsed candidate / exact v0.9.3</figcaption>'''+''.join(svg)+'''<p>Each dot is one of 53 newly enabled IV widths. Lower is faster. Five paired seeds; Ryzen 7 9700X; Zig 0.15.1. Setup and copying are included.</p><p>Scalar-only calls retain small costs: largest aggregate ratios 1.020 native / 1.015 portable. Full distributions and costs are retained in the report.</p></figure></body></html>'''
(p/'results.html').write_text(html)
