#!/usr/bin/env python3
import html,json,pathlib,sys
s=pathlib.Path(sys.argv[1]);d=json.loads((s/'summary.json').read_text())
rows=[]
for v in ['ready00','ready12']:
 for seed in [902902,902903,902904]:
  name=f'{"reverse" if seed==902904 else "confirm"}-{v}-{seed}.jsonl';rows.append((f'{v} · {seed}'+(' reversed' if seed==902904 else ''),d[name]['aggregate']))
for seed in [902902,902903]:rows.append((f'Unchanged · {seed}',d[f'confirm-candidate-{seed}.jsonl']['aggregate']))
x=lambda v:250+(v+.3)*235
svg=['<svg viewBox="0 0 700 352" role="img" aria-label="Repeated schedules are slower or near parity against v0.9.3">']
for tick in [0,.5,1,1.5]:
 xx=x(tick);svg.append(f'<line x1="{xx}" x2="{xx}" y1="24" y2="304" stroke="var(--border)" {"stroke-dasharray=\"4 4\"" if tick==0 else ""}/><text x="{xx}" y="326" text-anchor="middle" class="axis">{tick:+.1f}%</text>')
for i,(label,agg) in enumerate(rows):
 y=43+i*34;svg.append(f'<text x="0" y="{y+4}" class="label">{html.escape(label)}</text>')
 for op,dy,color in [('encrypt',-4,'--chart-1'),('decrypt',4,'--chart-2')]:
  val=(agg[op]['affected_median_of_cases']-1)*100;xx=x(val)
  svg.append(f'<circle cx="{xx}" cy="{y+dy}" r="4" fill="var({color})"><title>{html.escape(label)} {op}: {val:+.3f}% time</title></circle>')
svg.append('</svg>')
text='''<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;font-family:var(--font-sans)}svg{width:100%;height:352px;display:block}.label{font-size:12px;fill:var(--foreground)}.axis{font-size:11px;fill:var(--muted-foreground)}p{font-size:12px;color:var(--muted-foreground);margin:8px 0} .legend{display:flex;gap:18px;font-size:12px}.dot{display:inline-block;width:8px;height:8px;border-radius:50%;margin-right:5px}</style></head><body><div class="legend"><span><i class="dot" style="background:var(--chart-1)"></i>Encrypt</span><span><i class="dot" style="background:var(--chart-2)"></i>Decrypt</span></div>'''+''.join(svg)+'''<p>Time relative to exact v0.9.3; lower is faster. Median of 22 width-specific paired medians; 31 pairs per width. Dots are descriptive medians, with uncertainty detailed in the report.</p></body></html>'''
(s/'confirmation-chart.html').write_text(text)
