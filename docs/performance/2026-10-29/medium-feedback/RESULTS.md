# Medium CBC feedback batching against released v0.9.2

Retain CBC encryption batching for the measured IV register widths
**2, 3, 4, 8, 16, 24, 31, 32 and 63 blocks**. IV2 dispatch starts at 128 bytes,
IV3 at 48 bytes, and the others at 64 bytes. Unlisted medium widths keep their
original scalar path. Previously retained CBC64/65/128 and CFB64/128 batching
is preserved. The entire CFB production section, including scalar IV65, is
byte-for-byte unchanged from v0.9.2: medium CFB candidates failed short-call
controls, despite their large-message gains.

The baseline is exact released v0.9.2
`69d7ed3a2db775071fe331eb667b84283eaafb0d`, including bounded OCB and the
existing large-IV feedback paths. Cipher kernels are identical on both sides.
These are direct public-context measurements against that release, never sums
of gains isolated against older kernels or earlier releases.

## Measurements

The table below is whole 16 KiB encryption elapsed candidate/baseline, lower
is better. Every result includes public context initialization, IV and cipher
copying, plaintext copying, and encryption; allocation, random generation and
key expansion are excluded. GFNI setup inside encryptBlocks is included.

| CBC IV blocks | Native ratio (three run medians) | Portable ratio (three run medians) |
| ---: | --- | --- |
| 2 | 0.933960 (0.937531, 0.923637, 0.933960) | 0.623732 (0.619317, 0.623732, 0.628893) |
| 3 | 0.595246 (0.593412, 0.597056, 0.595246) | 0.720576 (0.720576, 0.716708, 0.721550) |
| 4 | 0.462187 (0.463531, 0.456745, 0.462187) | 0.365524 (0.367160, 0.365524, 0.361146) |
| 8 | 0.277126 (0.267262, 0.280118, 0.277126) | 0.430824 (0.430824, 0.439380, 0.428567) |
| 16 | 0.226446 (0.227403, 0.225214, 0.226446) | 0.437259 (0.437259, 0.440231, 0.436557) |
| 24 | 0.216729 (0.216729, 0.217253, 0.215602) | 0.431148 (0.431148, 0.429596, 0.431659) |
| 31 | 0.163845 (0.167326, 0.163845, 0.162549) | 0.445597 (0.445597, 0.454540, 0.442420) |
| 32 | 0.151777 (0.154677, 0.150464, 0.151777) | 0.439815 (0.439815, 0.440774, 0.430777) |
| 63 | 0.097391 (0.097082, 0.100478, 0.097391) | 0.431567 (0.434441, 0.429380, 0.431567) |

Split 16 KiB elapsed-time ratios:

| CBC IV blocks | Native split ratio | Portable split ratio |
| ---: | ---: | ---: |
| 2 | 0.935296 | 0.621375 |
| 3 | 0.603163 | 0.722651 |
| 4 | 0.457581 | 0.369238 |
| 8 | 0.280870 | 0.434818 |
| 16 | 0.227144 | 0.435721 |
| 24 | 0.216163 | 0.432206 |
| 31 | 0.163975 | 0.442930 |
| 32 | 0.153622 | 0.436786 |
| 63 | 0.100084 | 0.432576 |


Whole and split results, every tiny/threshold/ring/large case, all raw pair
ratios and the three separate run medians are in `final/summary.json` and
`final/summary.txt`. Split CBC uses two public calls after block 1. Split CFB
is an unchanged control after byte 1, including short continuation workloads
and long calls that enter with pending feedback. Full output is compared and
hashed outside timing after every pair. Setup and analysis are specified in
[COMMANDS.md](COMMANDS.md).

There are 1088 raw rows per run, six final runs, **6528 rows / 58752 measured
pairs**, with two warmup pairs before nine alternating measured pairs per row.
Repeated fixed/ring lengths are pooled within a run; 1992 distinct aggregate
cells remain across both targets. The three seeds vary runtime keys, IVs,
plaintext, unaligned/swapped buffers and module placement. The final run per
target reverses module declarations and labels; analysis inverts its ratios.
`control/` contains unchanged baseline-versus-baseline checks with three seeds
per target, including unaligned and swapped buffers. `excluded/` checks the
unlisted medium widths 5/7/9/15/17/23/25/30/33/62 with five seeds and reversed
placement, checking that restricting eligibility keeps those API workloads stable.

The final main matrix's worst aggregate unchanged/control ratios are
**1.015380 native** and **1.013563 portable**. The worst aggregate cell that
actually enters a newly enabled CBC helper is **0.977105 native** or
**0.838956 portable**. Thus no newly batched cell regresses in these aggregate
measurements; near-unity improvements are not separately claimed as wins.

The unchanged baseline-versus-baseline aggregate maxima are 1.017472 native
and 1.009558 portable. The excluded-width five-run aggregate maxima are
1.013840 native and 1.006751 portable. An initial native CFB62 split-32-byte
control had three run medians 0.994973/1.037020/1.110572; two extra seeds reduce
its five-run median to 1.008689. All original runs remain in the raw data.
These unchanged-code controls establish a local noise scale; they are not
performance gains.

Tiny differences within timing noise are not wins. Individual raw samples may
have larger scheduling/layout outliers; none are deleted. The historical broader
CBC range and every rejected CFB experiment are retained under `variants/`.
[EXPERIMENTS.md](EXPERIMENTS.md) identifies their exact sources, drivers,
short-call costs and why only CBC survived. Assembly/symbol captures are in
`assembly/`, including two rejected dispatcher configurations. Exported wrappers
provide a reproducible code-size comparison, rather than assuming every API
caller receives identical compiler decisions.

## State, validation and boundaries

A batch reads at most min(64, IV blocks, remaining full blocks) distinct ring
entries before replacing them, so it never crosses a feedback dependency.
Scratch is bounded to min(64, IV blocks) blocks; IV2/3 no longer reserve a
64-block temporary in their helper. IV2 retains a conservative 128-byte entry
threshold and a 64-byte loop threshold; IV3 uses a 48-byte loop threshold.
CBC length validation still occurs before every context/data write. The public
API, Cipher=352 bytes, context fields/offsets/size/alignment and circular indexing
are preserved. No new API, prepared-key cache, heap allocation, Cipher kernel,
OFB/CMAC/CTR/ACPKM implementation, root export, version or OpenSpec change occurs.

The two production feedback tests extend independent AES and Kuznechik physical
shift-register references to every newly enabled width. They cover all 16 buffer
alignments and guards, threshold and ring/batch crossings, CBC block splits,
empty updates, every pending CFB byte count, partial tails, short continuations,
inverse output, mixed encryption/decryption directions, and exact observable
head/register/used/stream/feedback state after each update. The reference inverse
also preserves stale stream/feedback after whole-block CFB decryption.
CBC rejection checks compare every context field and every guarded data byte;
`contracts.zig` additionally exercises invalid lengths 1/15/17/47/49/63/65/127/
129/255, including above every dispatch cutoff, after a valid prefix.
`continuation.zig` compares every context field with exact v0.9.2 while changing
direction on randomized continuing contexts. All existing RFC/all-mode and both
OCB schedule tests remain enabled.

| Configuration | Result |
| --- | --- |
| Exact v0.9.2 baseline native / portable ReleaseFast | 103 passed / 95 passed + 2 expected skips |
| Final native LLVM Debug / ReleaseSafe / ReleaseFast | 103 passed each |
| Final native default Debug | 95 passed + 3 expected skips |
| Final portable Debug / ReleaseSafe / ReleaseFast | 95 passed + 2 expected skips each |
| Final znver5-gfni / znver5-avx512vbmi, LLVM ReleaseFast | 95 passed + 3 expected skips each |
| Final linked AArch64 Linux GNU ReleaseSafe | Actual ARM aarch64 ELF test executable compiled |
| Layout and atomic rejection contracts / direction continuation | 8/8 each |
| Local final portable ReleaseSafe | 95 passed + 2 expected skips |


Fresh caches and actual named test inventories are checked in `checks.json`;
`validation/` retains complete receipts. Local final ReleaseSafe is recorded
separately. Default native Debug uses Zig's self-hosted backend and has an
additional expected skip; explicit LLVM Debug exercises the accelerated code.
The AArch64 check links an actual executable and records its file type/hash,
without attempting execution. Validation duration is not performance evidence.

## Reproduction, limits and cleanup

The exclusive Boat VM is **bx_g86mt7cz**, created as `kuz-medium-feedback` with
no environment or snapshots, TTL 10800 seconds. Ownership JSONL, machine/CPU,
compiler version/hash and source manifests are retained. Both native and portable
are compiler targets on that same AMD Ryzen 9 9950X guest, not different hardware.
Zig 0.15.1 archive SHA-256 is
`c61c5da6edeea14ca51ecd5e4520c6f4189ef5250383db33d01848293bfafe05`; executable
SHA-256 is `0ee27482eb2e7b19fad58579c107364aa93fbfb54be2d2b9c52cef5f955d6225`.
No other worker's VM or checkout was touched. VM copies are source-only and all
caches are disk-backed; compilation, validation and timing were serialized there.

`candidate-source.tar.gz`, `baseline-v0.9.2.tar.gz`, `prepare.py`, `run.sh`,
`run-tests.sh`, `control.sh`, `run-excluded.sh`, `after.sh`, `analyze.py`, `report.py`, `archive.py`
and `verify.py` support standalone reproduction and evidence verification.
`source-sha256.json` binds the complete source bundle; `vm-source-sha256.json`
binds the final remote library source to it. `SHA256SUMS` inventories evidence.

Residual hypotheses include reducing native IV2 setup/tail costs, comparing two versus three portable
lanes for IV3 while respecting the native padding tradeoff, independent
measurement of unlisted register widths, a CFB entry strategy that retains the
small scalar caller's code generation, and a genuinely distinct solution for
irregular large CFB rings. None is enabled or claimed as a win here. This is
finite warm-loop evidence on one virtualized CPU family/compiler, with no claim
of physical optimality, constant-time behavior, other CPUs or cold-cache gains.

All measured sources and raw data were downloaded and checked locally before deletion.
`boat-deleted.json` and `boat-deletion-status.json` retain request and completed
cleanup receipts for this assigned VM only. No push, PR, tag or release was made;
root owns review, integration and publication.
