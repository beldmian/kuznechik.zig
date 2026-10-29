#!/usr/bin/env python3
import json,pathlib,statistics,html
root=pathlib.Path(__file__).resolve().parent
cells=json.loads((root/'summary.json').read_text())
def get(target,mode,width,n=16384,split=False):
 return next(x for x in cells if (x['target'],x['mode'],x['m'],x['bytes'],x['split'])==(target,mode,width,n,split))
rows=[]
for mode,width in [('CBC-encrypt',64),('CBC-encrypt',65),('CBC-encrypt',128),('CFB-encrypt',64),('CFB-encrypt',128),('CFB-encrypt',65)]:
 a,b=get('native',mode,width),get('baseline',mode,width)
 rows.append(f"| {mode}, IV{width} | {a['median']:.6f} | {100*(1-a['median']):.1f}% | {b['median']:.6f} | {100*(1-b['median']):.1f}% |")
changed=[x for x in cells if x['bytes']>=64 and x['m']>=64 and (x['mode']=='CBC-encrypt' or x['m']&(x['m']-1)==0)]
controls=[x for x in cells if x not in changed]
body='''# CBC/CFB feedback batching against released v0.9.0

Retained: CBC independent-feedback batching for IV registers >=64 blocks;
CFB batching for power-of-two IV registers >=64 blocks (measured IV64/128).
CFB IV65 keeps the original scalar encryption algorithm after its broader
candidate failed a portable short-call control. Updates shorter than 64 bytes
use the original scalar algorithms. No data-layout or public API change.

## Whole 16 KiB encryption

Elapsed candidate / baseline ratios, lower is better. Baseline is unchanged
v0.9.0 `d42d82cd4ece09b6281aac58cdcbe6edef5d43b7`, including its released
cipher kernel. Reductions include context initialization, IV copying, plaintext
copying, and public mode encryption; key expansion and allocation are excluded.
These gains are measured directly and are not sums of earlier isolated results.

| Operation | Native ratio | Less time | Portable ratio | Less time |
| --- | ---: | ---: | ---: | ---: |
'''+ '\n'.join(rows)+'''

The IV65 CFB row is an unchanged-algorithm control, not a speed claim.
`summary.json` and `summary.txt` include every tiny/threshold/large/split cell
and every run median; the JSONL files preserve all samples and full-output
checksums. Split calls occur after byte 1 for CFB or block 1 for CBC.

'''
for t in ['native','baseline']:
 def show(xs):return max(x['median'] for x in xs if x['target']==t)
 body+=f"- {t}: worst aggregate control ratio {show(controls):.6f}; worst potentially batched cell {show(changed):.6f}.\n"
body+='\nSplit 16 KiB operations (same elapsed-time ratio):\n\n| Operation | Native | Portable |\n| --- | ---: | ---: |\n'
for mode,width in [('CBC-encrypt',64),('CBC-encrypt',65),('CBC-encrypt',128),('CFB-encrypt',64),('CFB-encrypt',128)]:
 body+=f"| {mode}, IV{width} | {get('native',mode,width,split=True)['median']:.6f} | {get('baseline',mode,width,split=True)['median']:.6f} |\n"
body+='''
None of the 672 aggregate cells exceeds 1.05. This is an aggregate regression
screen, not a claim that every individual noisy sample improved. See the
full run distributions in `summary.json`. Small differences within timing
noise are not speedups. In the retained configuration, the worst aggregate
ratio over all cells is below 1.03.

## Semantics and verification

Both loops encrypt at most `min(64, iv_blocks, remaining_full_blocks)` distinct
existing register entries before replacing them, including circular crossings.
CBC validates length before any write. CFB finishes pending feedback first,
then complete groups, then the original scalar tail. It updates the last
`stream` and `feedback` values exactly, even when `used == 16`. The private batch helper uses a bounded 64-block (1 KiB) stack buffer. No heap allocation,
field change, Cipher change, or decryption algorithm change is introduced.

The two new production tests use an independent byte shift-register reference
with single-block encryption for AES and Kuznechik. They cover IV1/2/3/63/64/65/128,
all 16 buffer alignments with guards, batch/IV wrap boundaries, all pending CFB
byte counts, CBC block splits, empty updates, continuation after partial tails,
full observable register/stream/feedback state, inverse output, and atomic CBC
length rejection. Existing RFC and authenticated-mode suites remain enabled.
`contracts.zig` compares every CBC/CFB field type/offset, size and alignment
against v0.9.0, and checks Cipher=352 bytes. `continuation.zig` independently
compares every context field and full output while changing direction on a
continuing context, including inverse paths that leave stale stream/feedback.

Final validation receipts:

| Target/backend | Baseline | Candidate |
| --- | --- | --- |
| Native LLVM Debug | 99 passed | 101 passed |
| Native ReleaseSafe | 99 passed | 101 passed |
| Native ReleaseFast | 99 passed | 101 passed |
| Native default Debug backend | 91 passed, 3 skips | 93 passed, 3 skips |
| Portable Debug/ReleaseSafe/ReleaseFast | 91 passed, 2 skips each | 93 passed, 2 skips each |
| AArch64 Linux ReleaseSafe | Test executable compiled | Test executable compiled |
| Context layout / direction continuation | — | 6/6 each (1 focused + 5 import-discovery tests) |
| Local zig build test ReleaseSafe | — | 93 passed, 2 skips |

Default native Debug uses Zig's self-hosted backend, which disables accelerated
paths and has an additional expected skip; the explicit LLVM Debug run covers
the full native suite. All cross-builds compile actual AArch64 ELF test
executables without attempting to execute them. Fresh disk-backed caches and
expected names/counts guard against stale test binaries.

## Reproduce and scope

Boat `bx_758ez2tt` (`kuz-ofb-r`), AMD Ryzen 9 9950X guest, Zig 0.15.1,
ReleaseFast, core 0. Native enables the guest's GFNI/AVX-512 block kernels;
`-mcpu=baseline` tests the portable backend on that same Zen 5 CPU, not a
separate older machine. Machine/compiler identity is in `lscpu.json`,
`uname.txt`, `zig-version.txt`, `compiler.sha256`, and `boat-owned.json`.

There are three runs per target, 336 cells per run, two warmup pairs plus nine
alternating measured pairs per cell: **18,144 measured pairs** in the final
six runs. Runtime keys, IVs and plaintexts vary with three seeds. Aligned,
unaligned and swapped buffers and reversed module placement control several
layout effects. Full outputs are compared and hashed after every pair.

Use `candidate-source.tar.gz` for a standalone source-only reproduction folder
at `/home/user/kuz-feedback-next`, then `bash run.sh` and `bash run-tests.sh`.
The bundle includes the exact baseline archive expected by the validation
runner. Or run `prepare.py` from this Git repository to create a fresh local
source-only folder. See `COMMANDS.md` for commands and timing boundaries,
`EXPERIMENTS.md` for rejected candidates, `source-sha256.txt` for every bundled
source/input hash and `SHA256SUMS` for the complete evidence inventory.
`analyze.py`, `report.py`, `archive.py` and `verify.py` regenerate the summaries,
report/chart, reproduction bundle, and validation of the receipts.

Limits: one virtualized CPU family, one compiler version, finite keys/lengths,
warm repeated operations, no universal speed or physical-optimality claim.
AES is a correctness adapter here, not a measured performance target. No
claim covers unmeasured IV widths, CPUs or compilers. Non-power-of-two CFB
batching remains a rejected hypothesis despite its large-message gains;
its tiny portable IV65 regression is preserved without omission.

All required source, raw measurements, identity, commands and exact test logs
were archived locally before the assigned VM was deleted. The deletion
request receipt is `boat-deleted.json` and completion is recorded in
`boat-deletion-status.json`; no other VM was touched. No push, PR, tag or
release was performed.
'''
(root/'RESULTS.md').write_text(body)
# A compact standalone figure; no external assets/scripts.
chart='''<!doctype html><html><head><meta charset="utf-8"><style>
body{font-family:var(--font-sans,system-ui);color:var(--foreground,#ddd);margin:0} p{font-size:13px;color:var(--muted-foreground,#aaa)}
figure{margin:0} .row{display:grid;grid-template-columns:115px 1fr 55px;align-items:center;gap:12px;margin:9px 0;font-size:13px}.track{height:18px;background:var(--secondary,#333);border-radius:3px}.fill{height:18px;background:var(--chart-1,#42a5f5);border-radius:3px}.portable{background:var(--chart-2,#66bb6a)} .legend{display:flex;gap:18px;font-size:12px}.dot{display:inline-block;width:10px;height:10px;background:var(--chart-1,#42a5f5);margin-right:5px}.dot.portable{background:var(--chart-2,#66bb6a)}
</style></head><body><figure><p>Whole 16 KiB encryption · elapsed time relative to unchanged v0.9.0 (100%)</p><div class="legend"><span><i class="dot"></i>Native</span><span><i class="dot portable"></i>Portable target</span></div>'''
for mode,m in [('CBC-encrypt',64),('CBC-encrypt',65),('CBC-encrypt',128),('CFB-encrypt',64),('CFB-encrypt',128)]:
 for target in ['native','baseline']:
  v=get(target,mode,m)['median']*100
  chart+=f'<div class="row"><span>{mode[:3]} · IV{m}</span><div class="track"><div class="fill {"portable" if target=="baseline" else ""}" style="width:{v:.4f}%"></div></div><span>{v:.1f}%</span></div>'
chart+='''<p>Median of three run medians; nine alternating measured pairs per cell after warmups. Zig 0.15.1, Ryzen 9 9950X guest. IV65 CFB stays scalar. Setup includes context initialization and input copying; key expansion is excluded.</p></figure></body></html>'''
(root/'results.html').write_text(chart)
