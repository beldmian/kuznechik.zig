#!/usr/bin/env python3
import html
import json
from pathlib import Path

p = Path(__file__).resolve().parent
rows = json.loads((p / 'summary.json').read_text())

def cell(target, mode, width, n=16384, split=False):
    return next(r for r in rows if (r['target'], r['mode'], r['m'], r['bytes'], r['split1']) == (target, mode, width, n, split))

selected = [('OFB-xor', 1), ('OFB-xor', 16), ('OFB-xor', 64), ('OFB-xor', 65)]
lines = ['# Retained feedback changes — measured results', '',
         'Zig 0.15.1 ReleaseFast; Boat Ryzen 9 9950X; 16 KiB complete operations, whole update. Ratios are elapsed optimized / elapsed v0.8.0, lower is better. Each value is the median of three run medians, each from seven alternating measured pairs after two warmup pairs.', '',
         '| Operation | Native ratio | Portable-target ratio |',
         '| --- | ---: | ---: |']
for mode, width in selected:
    a, b = cell('native', mode, width), cell('portable', mode, width)
    lines.append(f'| {mode}, m={width} | {a["median_ratio"]:.3f} | {b["median_ratio"]:.3f} |')
lines += ['', 'See `summary.json` for every short/long/split cell, per-run ratios and run ranges; `summary.txt` explicitly lists all ratios above 1.05. CFB, CMAC and OFB m=1/2/3/4/8/16 retain their original algorithms and serve as controls.', '',
          'All 73 original native root tests plus three new tests pass in ReleaseSafe and ReleaseFast: **76/76**. Portable root ReleaseSafe: **68 passed, 2 GFNI skips**, versus baseline 65 passed and 2 skips. The final local `zig build test -Doptimize=ReleaseSafe` also reports 68 passed, 2 skips. Static contracts confirm Cipher=352 bytes and unchanged mode sizes/alignments/field offsets.', '',
          'No allocation or public field change; ACPKM source is untouched. CFB production source is identical to baseline: its vector variants were rejected because small split operations regressed. OFB groups XOR and ring bookkeeping only for IVs of at least 64 blocks and runs of at least four already-generated blocks. CMAC direct-block processing was rejected for insufficient repeatable gain; its production source is identical to baseline.', '',
          'Scope: one virtualized Zen 5 machine, two compiler CPU targets, the measured seeds, lengths and partitions. Portable is the generic compiler backend on that same machine. Code-size and layout affect tiny messages; earlier CFB candidates and the OFB width-16 specialization were rejected after those controls. No universal speed or physical-optimality claim. VM contention/frequency effects and individual sample outliers remain possible.', '',
          '## Regression check', '']
slow = [r for r in rows if r['median_ratio'] > 1.05 and r['mode'] == 'OFB-xor' and r['m'] >= 64]
if slow:
    lines.append('The following cells exceed 1.05 across the three-run median and require an explicit retention decision:')
    for r in slow:
        lines.append(f'- {r["target"]} {r["mode"]} m={r["m"]}, bytes={r["bytes"]}, split1={r["split1"]}: {r["median_ratio"]:.3f}')
else:
    lines.append('No changed OFB configuration exceeds 1.05 in the median of three run medians. Individual noisy run cells are listed without omission in `summary.txt`; this threshold does not establish zero overhead for every possible workload.')
(p / 'RESULTS.md').write_text('\n'.join(lines) + '\n')
svg = ['<svg viewBox="0 0 680 250" role="img" aria-label="Elapsed time relative to v0.8.0 for 16 KiB complete operations; lower is better" style="width:100%;height:250px;font:12px var(--font-sans);fill:var(--foreground)">', '<line x1="590" x2="590" y1="25" y2="230" stroke="var(--muted-foreground)" stroke-dasharray="4 4"/>', '<text x="590" y="15" text-anchor="end">v0.8.0 = 100%</text>']
for i, (mode, width) in enumerate(selected):
    y = 40 + i * 47
    svg.append(f'<text x="0" y="{y + 18}">{html.escape(mode.replace("-encrypt", "").replace("-xor", ""))} m={width}{" (control)" if width < 64 else ""}</text>')
    for j, target in enumerate(['native', 'portable']):
        r = cell(target, mode, width)['median_ratio']
        w = 440 * r
        svg += [f'<rect x="150" y="{y+j*17}" width="{w:.1f}" height="12" rx="2" fill="var(--chart-{j+1})"/>', f'<text x="{155+w:.1f}" y="{y+j*17+10}">{r*100:.1f}%</text>']
svg.append('</svg>')
chart = '<!doctype html><html><head><meta charset="utf-8"><style>body{margin:0;color:var(--foreground);font-family:var(--font-sans)}p{margin:8px 0;color:var(--muted-foreground);font-size:13px}.legend{display:flex;gap:20px}.key{display:inline-block;width:10px;height:10px;border-radius:2px;margin-right:5px}</style></head><body><p>16 KiB complete mode operations · elapsed time relative to v0.8.0 · lower is better</p><p class="legend"><span><i class="key" style="background:var(--chart-1)"></i>Native Zen 5 target</span><span><i class="key" style="background:var(--chart-2)"></i>Portable x86_64 target</span></p>' + ''.join(svg) + '<p>Zig 0.15.1, Ryzen 9 9950X VM. Median of 3 seed/layout controls; 7 measured pairs each. Both targets run on the same CPU.</p></body></html>'
(p / 'results.html').write_text(chart)
