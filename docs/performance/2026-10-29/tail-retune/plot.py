#!/usr/bin/env python3
"""Make a small self-contained receipt chart from summary.json (no libraries)."""
import json, pathlib
root=pathlib.Path(__file__).resolve().parent
summary=json.loads((root/'summary.json').read_text())
names=['narrow-271828.jsonl','narrow-314159.jsonl','narrow-1618033.jsonl','reverse-818181.jsonl','narrow-2236067.jsonl']
names=[n for n in names if n in summary]
svg=['<svg viewBox="0 0 680 290" role="img" aria-label="Rejected candidate percent reduction in call time for standalone tails21 through23">']
for tick in range(-6,16,3):
 y=190-tick*11
 svg.append(f'<path d="M50 {y}H660" stroke="var(--border,#777)" stroke-dasharray="3 4"/><text x="42" y="{y+4}" text-anchor="end">{tick}%</text>')
for gi,(op,n) in enumerate((op,n) for n in (21,22,23) for op in ('encrypt','decrypt')):
 x=95+gi*105
 svg.append(f'<text x="{x}" y="285" text-anchor="middle">{op[:3]} {n}</text>')
 for ri,name in enumerate(names):
  row=next(d for d in summary[name]['cases'] if d['operation']==op and d['length']==n)
  ratio=row['median_ratio']
  if name.startswith('reverse'): ratio=1/ratio
  gain=(1-ratio)*100
  xx=x+(ri-(len(names)-1)/2)*10
  svg.append(f'<circle cx="{xx}" cy="{190-gain*11:.2f}" r="4" fill="var(--chart-{ri+1},currentColor)"><title>{name}: {gain:.2f}% less time</title></circle>')
svg.append('</svg>')
legend=' '.join(f'<span style="color:var(--chart-{i+1},currentColor)">● {name.split("-")[-1].split(".")[0]}</span>' for i,name in enumerate(names))
html='''<!doctype html><html><head><meta charset="utf-8"><style>
body{margin:0;font:13px var(--font-sans,system-ui);color:var(--foreground,#222)}svg{width:100%;height:290px}text{fill:currentColor;font-size:12px}p{margin:8px 0}.legend{display:flex;flex-wrap:wrap;gap:12px;font-size:12px}
</style></head><body><p><strong>Rejected Zen5 tail policy: early gains did not repeat</strong></p>'''+''.join(svg)+'<div class="legend">'+legend+'</div><p>Each dot is one run’s median paired ratio; hover for its value. CPU0 · Ryzen9950X guest · Zig0.15.1 ReleaseFast native. The final seed reversed some gains and larger tails regressed up to7.4%. No tail change retained.</p></body></html>'
(root/'results.html').write_text(html+'\n')
