# Exact-source reproduction

The tool-owned checkout starts at v0.9.3,
`567ab5e19531c2d746f6bfee489f58177933ea61`. No shell checkout/worktree was
created. `baseline-v0.9.3.tar.gz` is `git archive` of its complete src and build
files. The candidate changes only the CBC eligibility predicate and adds two
CBC tests. It does not use another worker's kernels.

```sh
python3 docs/performance/2026-10-29/cbc-remaining-widths/prepare.py
boat new --no-env --no-snapshots --ttl 10800 --name kuz-cbc-remaining-widths --json
# JSONL events were parsed individually; assigned exclusive VM bx_dzmcsqs6.
boat ssh bx_dzmcsqs6 'mkdir -p /home/user/cbc-widths /home/user/.cache/cbc-widths'
boat scp docs/performance/2026-10-29/cbc-remaining-widths/candidate-source.tar.gz bx_dzmcsqs6:/home/user/cbc-widths/source.tar.gz
boat scp /home/t3/.cache/kuz-other-toolchains/zig.tar.xz bx_dzmcsqs6:/home/user/zig.tar.xz
boat ssh bx_dzmcsqs6 'cd /home/user && tar xf zig.tar.xz && cd cbc-widths && tar xf source.tar.gz'
boat ssh bx_dzmcsqs6 'cd /home/user/cbc-widths && bash run.sh && bash run-tests.sh && bash after.sh'
```

Use a newly assigned VM for reproduction, never a deleted ID. The bundle is a
source-only folder, with no Git metadata, binary, toolchain or cache. All caches
are fresh disk-backed directories under `/home/t3/.cache` locally or
`/home/user/.cache` on the guest. Timed runs, compilation and tests are serialized
on that VM. Native and portable are compiler targets on the same guest.

`run.sh` builds ReleaseFast forward, reversed, and unchanged-baseline-control
binaries for `-mcpu=native` and `-mcpu=baseline`. Each target uses seed/layout
271828/0, 314159/3, 1618033/1. Layout 0 has aligned mode bytes; 3 and 1 are
unaligned by one byte, with layout 3 swapping the two output buffers. Reversed
placement swaps module declaration order and semantic labels, and analysis
inverts its paired ratios. The control uses two verbatim copies of v0.9.3.

Every repetition includes plaintext copy, public CBC initialization (including
Cipher and IV copy), and public encrypt: one whole call or two calls split after
block one. Allocation, runtime RNG, key expansion, reference encryption,
comparison, guard checks and checksums are outside timing. encryptBlocks
preparation and batch/scalar tails are inside encrypt's timing. Runtime keys,
IVs and inputs vary by seed. There is no hidden prepared-key cache. The context
and its cipher/register use their natural ABI alignment; byte slices intentionally
exercise aligned and unaligned callers.

Every pair checks both complete outputs against an independent physical
shift-register/single-block reference, checks prefix/suffix guards, and hashes
all output bytes. Memory barriers preserve timed output stores. Each row has
two warmup pairs followed by nine alternating measured pairs, with a 65536-byte
budget and at least eight repetitions. Thus 16 KiB rows process 131072 bytes
per side/sample. No independent minima are compared. Duplicate fixed/ring lengths
are pooled within each run; the aggregate is the median of the five per-run
medians, preserving all samples and noisy outliers.

The grid is IV1..65 plus IV128, whole/split, and lengths 16/32/48/64/80/112/
128/144/(IV*16-16)/(IV*16)/(IV*16+16)/(IV*32-16)/(IV*32+16)/1024/2048/16384,
omitting zero. Every final enabled width has actual public-API measurements.

`run-tests.sh` uses fresh caches for every target/mode, explicitly exercises
LLVM native Debug, keeps the all-mode and authenticated suites enabled, tests
three incomplete feature profiles, links an actual AArch64 test ELF, and runs
layout/atomic-rejection and exact-v0.9.3 direction-continuation drivers. The
verifier checks sequential named inventories, counts and specific CBC/OCB names.

```sh
python3 docs/performance/2026-10-29/cbc-remaining-widths/analyze.py
python3 docs/performance/2026-10-29/cbc-remaining-widths/verify.py
```

`evidence.tar.gz` holds unedited raw JSONL, complete validation receipts, VM source
hashes and machine/compiler identity. `*-summary.json.gz` contains all paired
ratios and per-run medians. `SHA256SUMS` inventories retained artifacts.

The initial three-seed whole-grid experiment is preserved in
`initial-analysis.txt`. Its unchanged baseline controls reached an aggregate
1.04781 native, while a newly dispatched scalar IV29 call reached 1.03256.
`after.sh` adds forward seed424242/layout0 and reversed8675309/layout3 for
every width and both targets, and the same two seeds in unchanged controls.
Those supplemental runs use the existing exact binaries, avoiding recompilation
as a source of change. It then captures exported CBC wrappers for all widths
with nm/assembly in both targets. The wrapper artifacts describe those exported
functions, not the code size of every possible caller. Original samples remain
in the raw archive and the original three runs remain visible in each final cell.
