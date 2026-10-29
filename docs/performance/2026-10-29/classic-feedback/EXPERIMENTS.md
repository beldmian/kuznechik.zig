# Classic feedback experiment record — 2026-10-29

Only large-IV OFB grouping is retained. `RESULTS.md` describes the accepted
patch; the chronology below preserves rejected candidates and their evidence.

The assigned checkout is `t3/optimize-cfb-ofb-cmac`, based on `5bbffcf`
(v0.8.0). Only `src/modes/classic.zig` and this evidence directory were edited.
No other checkout, VM, exports, version, release notes or OpenSpec files were
changed. The existing RFC-mode proposal authorizes measured optimization.

The owned VM was created with:

```sh
boat new --name kuz-feedback-p --ttl 7200 --no-env --type default --json
# bx_vvgmu7aw, AMD Ryzen 9 9950X, 4 vCPUs, disk-backed /home/user
boat scp /home/t3/.cache/kuz-other-toolchains/zig.tar.xz bx_vvgmu7aw:/home/user/zig.tar.xz
boat ssh bx_vvgmu7aw 'sha256sum zig.tar.xz; mkdir -p feedback/toolchain feedback/cache/local feedback/cache/global; tar -xf zig.tar.xz -C feedback/toolchain --strip-components=1; uname -a; lscpu; df -h /home/user; feedback/toolchain/zig version'
```

Archive SHA-256:
`c61c5da6edeea14ca51ecd5e4520c6f4189ef5250383db33d01848293bfafe05`.
Both local and remote compiler report Zig 0.15.1. Hardware and archive verification
are in `boat-hardware-compiler.log`. The retained compiler binary hash is in
`retained-compiler.log`.

Each source upload was made from the isolated worktree with `tar -czf`, including
`src`, `build.zig`, `build.zig.zon`, and the selected evidence harnesses. SHA-256
hashes of uploads are in `upload-sha256.txt`; the retained complete `src` tree and
harnesses are individually hashed in `retained-source-sha256.txt`. Remote folders
`feedback/{cfb,candidate,candidate2,candidate3,candidate4,candidate5,candidate6,final,retained,verified6,verified7,verified8}`
were separate extracted snapshots, not shared mutable source. The initial CFB
harness needed import-path fixes before it compiled; `cfb-paired.zig` and
`classic-before.zig` preserve the actual successfully compiled versions. Compiler caches
are unique disk-backed directories under `feedback/cache`; local caches are
under `/home/t3/.cache/kuz-feedback-p-20261029`. Local `TMPDIR` was also set there
because `/tmp` is nearly full tmpfs.

## Reproduction

The retained full sequence is `run-boat.sh`. From the extracted snapshot root:

```sh
bash docs/performance/2026-10-29/classic-feedback/run-boat.sh
```

The benchmark build command, with target/cache/output paths varied by experiment:

```sh
../toolchain/zig build-exe -O ReleaseFast -mcpu=native \
  --cache-dir ../cache/verified8-bench-native \
  --global-cache-dir ../cache/verified8-global \
  --dep kuz --dep before \
  -Mroot=docs/performance/2026-10-29/classic-feedback/paired.zig \
  -Mkuz=src/kuznechik.zig \
  -Mbefore=docs/performance/2026-10-29/classic-feedback/classic-before.zig \
  -femit-bin=../paired-retained-native
taskset -c 0 ../paired-retained-native 123 1048576 99 0
taskset -c 0 ../paired-retained-native 456 1048576 99 3
```

Portable builds use `-mcpu=x86_64`, separate caches and a 131072-byte repetition
budget. Native single-block encryption selects the existing Zen 5 hybrid
lookup/GFNI kernel; native block batches select the existing GFNI/batch policy.
Portable uses the existing generic lookup path. Both targets run on the same Zen 5 VM; portable means a compiler CPU
target and table-based cipher backend, not a different physical machine.

`classic-before.zig` is exactly the production portion of v0.8.0 classic.zig,
with its tests removed to avoid imports outside the baseline module. The complete
original, including tests, is `baseline-classic.zig.txt`. Before and after both
use the unchanged current `Cipher`. The benchmark measures CFB encryption, OFB
XOR and complete CMAC init/update/final operations. Cipher key expansion is
outside the timer; context setup (including CMAC subkeys), input copy and mode
processing/finalization are inside, identically for both implementations. Each
repetition starts from the same plaintext and a fresh context. Timer and checksum
work are outside the per-operation loop. An opaque memory barrier and output
escape prevent dead-store elimination. Every paired sample checks all output
bytes and all tag bytes; the JSONL includes checksums. It does not merely compare
one selected byte or a round-trip.

Lengths: 16, 64, 1024, 16384 bytes. IV widths: 1, 2, 3, 4, 8, 16, 64, 65 blocks
for feedback modes. Each has a whole update and a 1-byte prefix update followed
by the remainder. There are two warmup pairs and seven measured pairs per cell,
with alternating before/after order. Seeds 123/456 change keys, IVs and inputs;
layout 0 is aligned, layout 3 is unaligned by one byte and swaps output buffers.
A separately compiled harness swaps baseline/optimized nominal-type order,
uses seed 789/layout 1, and reverses the ratio interpretation in analysis. This
is a code-instantiation-order control, not proof that every machine-code layout
has been controlled. There are 136 cells/run and six retained runs. The
`analyze.py` script verifies these counts, reports median paired ratios per run,
then the median of those three run medians per configuration. All raw paired
nanosecond samples are retained.

Earlier `.log` benchmark files print Zig arrays with `{ ... }`; replace those
array braces with `[ ... ]` to parse their otherwise JSON records. Later `.jsonl`
files are valid JSON directly. These earlier files remain unmodified raw output.

## Candidate chronology and rejection decisions

- `cfb-*`: first complete-block vector XOR/feedback path in CFB encryption.
  Serial cipher dependencies remain serial. It improved full messages, but
  introduced a short-fragment branch cost.
- `candidate-*` / `candidate1-*`: first CFB path, simple full-block OFB XOR,
  direct full-block CMAC processing that retains the last possible final block.
  Two seeds on native and portable targets. CMAC was essentially neutral (most
  long-message ratios around 0.98–1.02) and was **rejected**, despite correctness.
  Simple OFB XOR was also too small/inconsistent to justify retention.
- `candidate2-*`: CFB branches on the already-computed segment size. OFB batches
  XOR across a run of already-generated register blocks. Native width 65 gained
  about 27–28%, but widths 2 and 3 regressed 11–19%; that unrestricted OFB variant
  was **rejected**. All 76 native ReleaseSafe tests passed for this candidate.
- `candidate3-*`: omit grouping for widths below 4 and runs below 4 blocks.
  Crossover measurements found little long-message gain for widths 4/8, gains
  around 6–9% for width 16, and substantial gains for widths 64/65. Retain grouping
  only for IVs of at least 16 blocks and runs of at least 4 full blocks.
- `final-attempt1/`: full native and portable suites and three layout/seed runs
  for that intermediate source. Native short split CFB at width 64 regressed
  about 11–14% in two normal-order runs, despite long-message gains. This source
  was **rejected**. Its exact source is `final-attempt1-classic.zig.txt`.
- `candidate4-*`: separate XOR loop then feedback copy, instead of explicit
  full-block vector handling. Still had short-fragment regressions and smaller
  full-message gains; **rejected**.
- `candidate5-*` and `attempt2/`: specialize short (<16 byte) encryption calls
  separately so they retain the existing byte loop. This improved short updates,
  but full controls found a portable width-64 split-16-byte regression (median
  1.065 across three runs). Inspection showed the larger public encrypt function
  had an outlined public encrypt function whereas the baseline had no such
  symbol. This was a code-size/layout observation, not a proven causal diagnosis.
  This form was **rejected**.
- `candidate6-*` and the retained runs: isolate the full-block specialization in
  a private `noinline` helper. This reduces the full-block code mixed into the
  short path, removing the repeated regression in the preliminary checks. The
  public encrypt symbol still exists: the result cannot be attributed solely
  to restored inlining.
  CFB inverse code and its batching stay the same. CMAC production source is
  identical to baseline. ACPKM's existing M1 shortcut is untouched. This is a
  compiler-sensitive code-size/layout decision, not cipher parallelization.

Exact classic-source snapshots are retained as `.zig.txt`. Per-stage harnesses
are `cfb-paired.zig`, `candidate{1,2,3}-paired.zig`; candidates 4/5/6 and the retained
runs use `paired.zig` (the printing format changed, not timed operations).

## Validation semantics

Three added root tests compare AES and Kuznechik feedback against a physically
shifted byte-register reference and CMAC against a one-shot reference with
byte-wise GF subkey doubling. Feedback coverage includes widths 1/2/3/16/64/65,
all two-update splits of an 81-byte message, long splits on both sides of
64-block and ring boundaries through 2097 bytes, empty updates, inverse output,
and all 16 byte offsets with guard checks. CMAC covers lengths 0–81 plus long
exact/partial-block lengths, all short splits, selected long splits, one-byte
updates, independent tags, repeated snapshot finalization followed by append,
and read-only input preservation. Existing RFC/stdAES/Kuz, ACPKM section/rekey,
negative-input and authentication-before-plaintext tests remain in the full suite.

`contracts.zig` independently checks Cipher remains 352 bytes and all mode sizes,
alignments and field offsets equal v0.8.0 for the measured relevant IV widths.
No allocation, public context field, block API, counter rule, input rejection or
authentication flow is changed. The OFB grouping only consumes already-generated
keystream blocks: cipher batching and register precomputation order are unchanged;
`stream`, `head` and `used` preserve their old state at every update boundary.

Claims are limited to this compiler, backend, VM CPU and measured lengths/splits.
These are complete operations on fresh contexts, not a proof about sustained
contexts with every possible partition. Small sub-percent differences and
isolated noisy cells are not treated as speedups. No universal speed or physical
optimality claim is made, and M1 feedback encryption was not parallelized.

The final noinline-helper check is retained separately as `attempt3/`: its CFB
width-2 split-16-byte cell varied from 0.959 to 1.087 by control (median 1.054),
while OFB width-16 split-64-byte had a more consistent 1.045–1.062 overhead.
The final adjustment checks that 64 input bytes remain *before* calculating the
OFB batch count. It preserves exactly the same eligible batches and register
state, but avoids count arithmetic on fallback-only short calls. This final
source is `retained-classic.zig.txt` and was uploaded as `source-verified7.tar.gz`.
Native ReleaseSafe, native ReleaseFast, portable ReleaseSafe and the local build
were rerun after that adjustment. The old intermediate runs remain evidence,
not retained performance claims. Source directory names and cache names in
`run-boat.sh` make this last run distinct from earlier candidates.

## Final retention decision

`attempt4/` preserves the full verified7 experiment. The early OFB length guard
still left about 6.7% overhead for a split 64-byte message with a 16-block IV.
The CFB width-2 short split case also remained sensitive to layout (about 5.2%
median overhead in that run). Accordingly **all CFB production changes were
rejected**, including the private noinline helper, and **OFB grouping for widths
below 64 was rejected**. Complete CFB and CMAC production code is byte-for-byte
identical to baseline. The final retained patch only groups OFB XOR/bookkeeping
for IV widths of at least 64 blocks and runs of at least four full blocks.
Widths 64 and 65 showed large repeatable gain; smaller widths use the existing
algorithm. No claim is made about a universally optimal threshold.

The retained exact source is now `retained-classic.zig.txt`, uploaded as
`source-verified8.tar.gz`. `run-boat.sh` uses fresh `verified8-*` disk caches and
reruns all native/portable tests and all six benchmark controls. The new CFB and
CMAC reference tests remain useful regression coverage even though those
production candidates were dropped. `RESULTS.md` describes only this final
retained patch; intermediate performance numbers above are rejection evidence.

Final count/name verification confirmed 76 distinct native test names in both
optimization modes, 70 portable names (68 passes, two skips), and preservation of
all baseline local names. All paths in `retained-source-sha256.txt` were rehashed
against the final worktree. The six completed raw runs each contain exactly 136
cells (816 total). Analysis deliberately rejects partial output files. The final
binary manifest was regenerated after the run to avoid ambiguous entries from
exploratory artifact names reused before the final collection.

Diagnostic `backend-info.log` confirms native `znver5` with GFNI/AVX2/AVX512VL,
and portable `x86_64` with those features absent. AES adapters provide correctness
references only; only Kuznechik performance was measured. Small differences in
unchanged algorithms serve as a check on VM/layout/timing variation.

The owned VM `bx_vvgmu7aw` was deleted after collection with
`boat delete bx_vvgmu7aw --yes --json`. Deletion operation
`bdop_f1110a8c0f3a4393a489ae26d2537830` reports **completed** at
2026-10-29 09:39:12.800 UTC; both request and final status are preserved in
`boat-cleanup*.json`. No other VM was used or modified.

Final evidence checks are reproducible from the repository root:

```sh
python3 docs/performance/2026-10-29/classic-feedback/analyze.py
python3 docs/performance/2026-10-29/classic-feedback/make-report.py
python3 docs/performance/2026-10-29/classic-feedback/validate-evidence.py
```

The source-only `git diff --check` passes. A check of the entire evidence patch
also reports blank lines at EOF in five raw Zig build logs and the exact
baseline production excerpt. Those bytes are preserved intentionally as raw
output / exact baseline source, rather than normalizing the evidence.
