# Two-block GFNI investigation: reject production change

Baseline: released v0.9.3, `567ab5e19531c2d746f6bfee489f58177933ea61`.
Machine: exclusively owned Boat `bx_7rdh5mn8`, AMD Ryzen 9 9950X, affinity CPU 1.
Toolchain: Zig 0.15.1 LLVM, native ReleaseFast, supplied archive/executable hashes
verified (`machine.txt`). Production `src/` is restored byte-for-byte to v0.9.3.
Only evidence is committed. No push, PR, tag or release was made.

The narrower matrix wins the runtime-length harness but loses actual fixed-pair
public-API calls in both directions and costs complete CBC IV2 encryption time.
It therefore fails the requested sustained-benefit criterion. No gains are
integrated, added across baselines, or claimed as a physical optimum.

## Measured results

All ratios are candidate/baseline matched sample ratios, summarized as the median
of run medians. Each baseline below is exact v0.9.3. These are distinct call
shapes; do not combine their gains. `results.json.gz` and `summary.json.gz`
contain all summaries, including noisy observations and other lengths.

| Public workload | YMM switch / v0.9.3 | Range of run medians |
|---|---:|---:|
| Runtime-length dependent pair encrypt | 0.9399 | 0.9362–0.9454 |
| Runtime-length dependent pair decrypt | 0.9655 | 0.9611–0.9664 |
| Runtime-length independent pairs encrypt | 0.8275 | 0.8266–0.8301 |
| Runtime-length independent pairs decrypt | 0.8149 | 0.8058–0.8220 |
| Fixed-pair dependent encrypt | **1.0174** | 1.0168–1.0239 |
| Fixed-pair dependent decrypt | **1.0622** | 1.0439–1.0653 |
| Fixed-pair independent encrypt | **1.0462** | 1.0420–1.0482 |
| Fixed-pair independent decrypt | **1.0415** | 1.0350–1.0471 |
| Complete CBC IV2 encrypt, 128 bytes, fixed-pair harness | **1.0150** | 1.0143–1.0238 |
| Complete CBC IV2 encrypt, 1024 bytes, same harness | **1.0216** | 1.0203–1.0228 |
| Complete CBC IV2 encrypt, 16384 bytes, same harness | **1.0218** | 1.0207–1.0229 |

The switch comparison has two seeds, reversed module placement, swapped buffers
and different offsets: four runs, 15 pairs each in the broad pilot and 21 pairs
each in the fixed-pair rejection. The earlier equality-dispatch finalist has
six runs, three seeds, both placements, and 21 pairs each. It improved independent
runtime-length pairs by 17–19%, but added a persistent length-3 encryption cost:
run medians 1.0193–1.0406, median 1.0303. Moving the equality check into the
padding helper did not resolve that cost. The switch removed it in both-placement
pilots, but did not resolve the fixed-pair/CBC costs above.

Unchanged baseline-v-baseline pair controls were near unity (dependent encrypt
median 1.0029, decrypt 1.0073; independent 1.0030/0.9946). Portable pair controls
were 1.0019/1.0011 dependent and 1.0006/0.9962 independent. Every requested block
control was measured: direct singleton, lengths 1/3/4/5/8/16/24/25/31/63/64/65,
and 1024-block bulk. CBC also includes sub-entry controls and complete calls
from 128 bytes through 16 KiB. Full costs remain in the summaries/archive.

A fixed-copy ZMM helper was also tested. In a restricted harness it beat the YMM
candidate by roughly 4–5% on independent pairs/dependent decryption; that comparison
uses the YMM candidate as its reference, not v0.9.3. Direct comparisons of the ZMM
helper plus switch against v0.9.3 then showed no useful gain (pair medians about
0.999–1.008). It is rejected too. The contradictory-looking pilot result is a
warning about different compiler call shapes, not an additional baseline gain.

## Kernels, assembly and boundaries

The new YMM matrix has two independent 128-bit lanes, sixteen cyclic diagonals
of each L direction, lane-local rotations and GFNI multiplication in the existing
AES-field isomorphism. Key addition and inverse endpoints were preserved. Every
assembly input lane is defined, including duplicated upper lanes when widening
only substitution. The private predicate extends the unchanged `gfni.supported`
with VL; selection is restricted to `znver5`. Missing VL/AVX2 and backend profiles
retain their original paths; the existing 512-bit kernel was never disabled.

Two correct substitutions were measured. The mixed implementation uses one
`vinserti64x4`, two ZMM `vpermi2b`, one mask extraction and one masked selection;
there is no low-half extraction instruction. The proper YMM implementation
requires four `vpermi2b`, a bit-6 test, mask extraction and three selections. Both
linear bodies use 16 YMM GFNI multiplies, 15 lane-local rotations and seven LLVM
ternary XOR reductions. See `assembly-audit.json` for the archived YMM executable.
The fully YMM S-box was slower than the widened-substitution variant.

In the fixed-pair harness LLVM inlines and specializes the original public call:
its 32-byte YMM load already defines the unused upper ZMM lanes as zero. The
existing ZMM matrix avoids the new per-round widening step. Field/key conversion
instructions follow the timer start and remain in the timed round bodies;
`timing-boundary-audit.py`, its JSON output, and the full assemblies support
inspection. Instruction counts alone never justify a production change.

Keys, IVs and inputs are generated from runtime seeds. Block buffers meet only
the public 16-byte alignment requirement at controlled offsets; mode bytes are
unaligned. Each pair alternates baseline/candidate order after two validated
warmup pairs. Complete output, surrounding guards, CBC register/head state and
observable checksums are checked outside timing. Independent work cycles through
64 disjoint pairs; dependent work repeatedly updates one pair.

Cipher initialization/key expansion, allocation and between-sample resets are
outside block timing. Padding, API key conversion, transpose/copies and compiler
emitted per-call Cipher copies remain inside. The workload-frame Cipher copy is
outside. Complete CBC additionally times initialization and plaintext copying on
each repetition. No prepared-key cache was introduced. No independent minima or
noise filtering are used. VM scheduling/frequency and compiler call-shape effects
limit generalization to other CPUs, toolchains and consumers.

## Correctness

The cleaned YMM/equality candidate (`candidate/`) was tested with the full mode
suite and five additional tests: all substitution bytes in both lanes, independent
binary bases of both linear maps, fresh/zero/FF keys with arbitrary ciphertext,
whole-buffer guards and legal 16-byte offsets, CBC IV2 against basic transforms
with unaligned bytes/final state, and two-block residuals after bulk chunks.
The switch/inside/wide alternatives have complete-output/reference/guard checks
in their public-API harnesses; they are not claimed to have this full test matrix.

| Configuration of cleaned YMM/equality candidate | Actual sequential results |
|---|---|
| Exact baseline, native LLVM ReleaseFast | 103 passed |
| Native LLVM Debug / ReleaseSafe / ReleaseFast | 108 passed each |
| Portable LLVM Debug / ReleaseSafe / ReleaseFast | 95 passed, 2 expected skips each |
| Native self-hosted Debug | 95 passed, 3 backend skips |
| `znver5-avx2`, `znver5-gfni`, `znver5-avx512vbmi` | 95 passed, 3 skips each |
| `znver5-avx512vl` | 102 passed, 6 skips (hybrid + five new tests) |
| Proper-YMM substitution prototype, native Fast | 106 passed |
| Linked AArch64 ReleaseSafe test executable | statically linked AArch64 ELF produced |

The missing-VL run still executes the original GFNI tests; only the hybrid and
new pair tests skip. The v0.9.3 missing-AVX2 feature-gate fix is preserved.
`test-audit.jsonl` records actual names/counts, audited locally from full sequential
logs. Debug acceleration explicitly uses `-fllvm`. Every configuration has fresh
disk-backed caches under `/home/user/.cache`; local checks use `/home/t3/.cache`.
The initial exploratory validation was superseded after three complete runs;
its partial logs remain in `initial-validation/`, not in the completed counts.

## Evidence and exact reproduction

`evidence.tar.gz` (SHA-256 in `evidence.sha256`) contains 38 timing files with
**33,768 matched measurement pairs**, full source copies, all emitted assemblies,
13 complete sequential test logs, AArch64 link metadata, source/binary hashes,
rejected alternatives and noisy costs. `verify-archive.py` verifies 358 source
hashes, compares the baseline with the exact git object, checks every experimental
non-owned source file is unchanged, and confirms production source is restored.
`raw-audit.py` checks every case's contiguous pair numbers/counts. The initial
setup overwrite exception is disclosed in `pilot-limitations.txt`; that lost
pilot is excluded from all claims. Warmups were validated but not recorded as
measurement samples.

Archive directory mapping:

| Timing directory/files | Source and driver |
|---|---|
| `logs/`, `final/` | `initial-candidate/` as candidate; `bench.zig`, `reverse.zig`, `narrow.zig`, `control.zig` |
| `retained/` (historical name; nothing retained in production) | cleaned `candidate/`, `bench.zig` / `reverse.zig` |
| `controls/inside*`, `switch*` | corresponding source directories and drivers |
| `controls/wide-control*` | candidate versus `wide/`; restricted harness, different reference |
| `controls/wide-switch*` | baseline versus `wide-switch/`; broad harness |
| `controls/fixed-switch*` | baseline versus `switch/`; fixed-pair public API harness |

Run `python3 docs/performance/2026-10-29/gfni-pair/prepare.py` to extract source-only
copies under `/home/t3/.cache/kuz-gfni-pair-reproduce/candidate`; use `--phase initial`
for the earlier pilot/broad source. No checkout is created. Transfer the resulting
`transfer.tar.gz` and the specified Zig archive to a **newly owned** VM. Verify the
supplied toolchain hashes, extract under `/home/user/gfni-pair` and `/home/user`.
Use `run.sh` / `final.sh` for the initial phase; `retained.sh` for cleaned YMM;
`controls.sh`, `wide-switch-run.sh`, and **`fixed-run.sh`** for the rejection controls.
All compilation/tests/timed runs must be serialized. The fixed runs use 262144
blocks per sample, 21 pairs, seeds 745123 and 912345, layouts 0 and 3. Broad
finalists use 524288 blocks, 21 pairs, seeds 745123/912345/221133, layouts 0/3/2.
`report.py EXTRACTED_ARCHIVE` regenerates all paired summaries.

The owned VM was deleted after local verification. Boat confirms operation
`bdop_bb149b0a04954c74b649f4cabdf6a4ee` completed at
`2026-10-29T13:43:13.975Z`; see `cleanup.json` and deletion JSON. No other worker's
VM was accessed. No resource remains allocated by this investigation.
