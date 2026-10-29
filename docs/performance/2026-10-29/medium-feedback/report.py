#!/usr/bin/env python3
from pathlib import Path
import json
p=Path(__file__).resolve().parent
cells=json.loads((p/'final/summary.json').read_text())
rows=[];table=['| CBC IV blocks | Native ratio (three run medians) | Portable ratio (three run medians) |','| ---: | --- | --- |']
for w in [2,3,4,8,16,24,31,32,63]:
 cs=[next(c for c in cells if c['target']==t and c['mode']=='CBC-encrypt' and c['m']==w and c['bytes']==16384 and not c['split']) for t in ['native','baseline']]
 table.append('| '+str(w)+' | '+' | '.join(f"{c['median']:.6f} ("+', '.join(f"{r['median']:.6f}" for r in c['runs'])+')' for c in cs)+' |')
 bars=''.join(f'<div class="series"><span style="width:{(1-c["median"])*100:.2f}%;background:var(--chart-{i+1})"></span><b>{(1-c["median"])*100:.1f}%</b></div>' for i,c in enumerate(cs))
 rows.append(f'<div class="row"><strong>IV{w}</strong><div class="bars">{bars}</div></div>')
html='''<!doctype html><html><head><meta charset="utf-8"><style>
body{margin:0;color:var(--foreground);font-family:var(--font-sans)}p{color:var(--muted-foreground);line-height:1.45}.row{display:grid;grid-template-columns:45px 1fr;gap:10px;margin:10px 0;align-items:center}.series{position:relative;height:13px;margin:3px 0;background:var(--secondary);border-radius:3px}.series span{display:block;height:13px;border-radius:3px}.series b{position:absolute;right:5px;top:-1px;font-size:11px;font-weight:500;color:var(--foreground)}.legend{display:flex;gap:20px;font-size:12px}.dot{display:inline-block;width:9px;height:9px;margin-right:5px;border-radius:2px}.row strong{font-size:13px}small{font-size:11px;color:var(--muted-foreground)}
</style></head><body><p>CBC whole 16 KiB · less elapsed time versus exact v0.9.2</p><div class="legend"><span><i class="dot" style="background:var(--chart-1)"></i>Native target</span><span><i class="dot" style="background:var(--chart-2)"></i>Portable target, same CPU</span></div>'''+''.join(rows)+'''<small>Public context init + input copy + encrypt. Key expansion excluded. Median of three run medians; Zig 0.15.1, Ryzen 9 9950X guest. CFB candidates rejected for short-call costs.</small></body></html>'''
(p/'results.html').write_text(html)
(p/'large-table.md').write_text('\n'.join(table)+'\n')
