#!/usr/bin/env python3
import html,json,pathlib,sys
s=pathlib.Path(sys.argv[1]);data=json.loads((s/'summary.json').read_text());rows=[]
for v,label in [('candidate','Unchanged copy'),('explicit-clobber','Explicit + clobber'),('explicit-read','Explicit read')]:
 for placement,seed in [('forward',944001),('forward',944002),('reverse',944003)]:
  d=data[f'{v}-{placement}-{seed}.jsonl']['affected']; rows.append((f'{label} · '+('reverse' if placement=='reverse' else str(seed)),d))
x0=220;scale=7500;lo=min(d[k] for _,d in rows for k in ['encrypt','decrypt']);hi=max(d[k] for _,d in rows for k in ['encrypt','decrypt']);delta=max(abs(lo-1),abs(hi-1),0.005)*1.3;scale=140/delta
parts=['<!doctype html><meta charset="utf-8"><style>body{margin:0;font:13px var(--font-sans);color:var(--foreground)}svg{width:100%;height:330px}text{fill:var(--foreground);font:12px var(--font-sans)}.note{color:var(--muted-foreground);font-size:12px}</style><div class="note">Median candidate / v0.9.4 elapsed-time ratio across 22 affected widths. Lower is faster. Each width uses 31 paired samples.</div><svg viewBox="0 0 720 330" role="img" aria-label="Paired encryption and decryption ratios">']
zero=425
parts += [f'<line x1="{zero}" x2="{zero}" y1="20" y2="305" stroke="var(--border)"/>',f'<text x="{zero}" y="15" text-anchor="middle">1.000</text>']
for i,(label,d) in enumerate(rows):
 y=37+i*30;parts.append(f'<text x="0" y="{y+4}">{html.escape(label)}</text>')
 for k,color,dy in [('encrypt','var(--chart-1)',-3),('decrypt','var(--chart-2)',5)]:
  x=zero+(d[k]-1)*scale
  parts += [f'<line x1="{zero}" x2="{x:.2f}" y1="{y+dy}" y2="{y+dy}" stroke="{color}" stroke-width="3"/>',f'<circle cx="{x:.2f}" cy="{y+dy}" r="3" fill="{color}"/>']
 parts.append(f'<text x="715" y="{y+4}" text-anchor="end">{d["encrypt"]:.4f} / {d["decrypt"]:.4f}</text>')
parts.append('<text x="0" y="325">Encryption / decryption</text><rect x="160" y="315" width="12" height="4" fill="var(--chart-1)"/><rect x="180" y="315" width="12" height="4" fill="var(--chart-2)"/></svg><div class="note">One Ryzen 9 9950X guest, Zig 0.15.1. These observations do not establish physical optimality.</div>')
(s/'comparison.html').write_text(''.join(parts))
