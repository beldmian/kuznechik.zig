#!/usr/bin/env python3
from pathlib import Path
import math,html
P=Path(__file__).resolve().parent
rows=[]
for line in (P/'results.md').read_text().splitlines():
 if line.startswith('| native |') or line.startswith('| x86_64 |'):
  target,work,op,gain,control=[v.strip() for v in line.strip('|').split('|')]
  rows.append(dict(target=target,work=work,op=op,gain=float(gain),control=float(control)))
lo=min(-2,math.floor(min(r['control'] for r in rows))-1)
hi=math.ceil(max(r['gain'] for r in rows)/10)*10
pos=lambda v:100*(v-lo)/(hi-lo)
parts=['''<!doctype html><html><head><meta charset="utf-8"><style>
body{margin:0;color:var(--foreground);font-family:var(--font-sans);font-size:13px}p{line-height:1.5;margin:0 0 14px}.muted{color:var(--muted-foreground)}.legend{display:flex;gap:18px;margin-bottom:12px}.dot{display:inline-block;width:9px;height:9px;border-radius:50%;margin-right:6px}.group{margin-bottom:12px}.label{font-size:12px;color:var(--muted-foreground);margin-bottom:3px}.row{display:grid;grid-template-columns:65px 1fr 56px;gap:8px;align-items:center}.plot{height:22px;position:relative;border-bottom:1px solid var(--border)}.bar{position:absolute;top:5px;height:12px;background:var(--chart-1);border-radius:2px}.zero{position:absolute;top:0;bottom:0;border-left:1px solid var(--muted-foreground);opacity:.5}.control{position:absolute;width:5px;height:5px;top:8px;border-radius:50%;background:var(--foreground)}.num{text-align:right;font-family:var(--font-mono)}.scale{display:flex;justify-content:space-between;margin-left:73px;margin-right:64px;font-size:11px;color:var(--muted-foreground)}
</style></head><body><p>Median paired wall-time saved by bounded OCB setup.<br><span class="muted">Three seeds · both module layouts · seven alternating pairs · Zen 5 VM</span></p><div class="legend"><span><i class="dot" style="background:var(--chart-1)"></i>Native target</span><span><i class="dot" style="background:var(--chart-2)"></i>Portable target</span><span>● Baseline control</span></div>''']
for work in dict.fromkeys(r['work'] for r in rows):
 for op in ['seal','open']:
  parts.append('<div class="group"><div class="label">'+html.escape(work)+' · '+op+'</div>')
  for target in ['native','x86_64']:
   r=next(r for r in rows if r['work']==work and r['op']==op and r['target']==target)
   v=r['gain']; start=min(pos(0),pos(v)); width=abs(pos(v)-pos(0)); color='--chart-1' if target=='native' else '--chart-2'
   parts.append(f'<div class="row"><span>{"Native" if target=="native" else "Portable"}</span><div class="plot"><i class="zero" style="left:{pos(0):.3f}%"></i><i class="bar" style="left:{start:.3f}%;width:{width:.3f}%;background:var({color})"></i><i class="control" title="Baseline control {r["control"]:.2f}%" style="left:{pos(r["control"]):.3f}%"></i></div><span class="num">{v:.1f}%</span></div>')
  parts.append('</div>')
parts.append(f'<div class="scale"><span>{lo}%</span><span>{hi}%</span></div><p class="muted" style="margin-top:14px">Complete public seal/open calls, including input reset; key setup and allocation excluded. Positive means faster. Large-call differences are near the control noise. VM results do not establish universal hardware gains.</p></body></html>')
(P/'comparison.html').write_text(''.join(parts))
