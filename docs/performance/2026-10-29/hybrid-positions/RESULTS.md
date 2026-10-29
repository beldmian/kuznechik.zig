# Hybrid byte-position subsets: retain released prefix policy

Compared only against released **v0.9.1**, main
`a518ff4aed72f1d9cfe8b923944ca68ec39b2d0f` (the peeled v0.9.1 tag).
**No production change is retained.** The released five GFNI positions
`[0,1,2,3,4]`, eleven lookup rows and three GPR chains remain unchanged.
The tested alternatives did not yield a repeatable win in both public direct
block APIs. This is useful rejection evidence for approved task 4.3, not a
claim that the retained subset is optimal.

## Repeated public direct-API results

Elapsed candidate/released ratios; lower is faster. Each entry is the median
of **31 alternating paired samples**, after three warmup pairs. Each sample
contains 524,288 dependent actual `Cipher.encrypt` or `Cipher.decrypt` calls.
Two runtime seeds use normal module placement; the third reverses module
placement and the analysis inverts raw paired ratios. Input addresses rotate
through four legal 16-byte offsets modulo 64; buffers alternate roles.

positions | seed 94201 enc / dec | seed 94202 enc / dec | reversed seed 94203 enc / dec
--- | ---: | ---: | ---:
[0, 6, 7, 8, 9] | 1.004770 / 1.008919 | 1.011983 / 1.020057 | 1.010104 / 1.018236
[0, 1, 8, 9, 10] | 1.004872 / 1.022718 | 1.010658 / 1.021334 | 1.006479 / 1.013139
[0, 3, 6, 9, 12] | 1.020576 / 1.021815 | 1.016724 / 1.034880 | 1.003610 / 1.034148


All nine finalist/run combinations regress both direct directions. Some
individual encryption differences are sub-percent and unresolved within noise;
the results do not support retaining a new choice. For example, the split
subset saves static instructions but its direct decryption regresses
2.27%, 2.13% and 1.31% across these runs. The spaced subset's exploratory direct
decrypt ratio of 0.983988 does not reproduce: confirmations are
1.021815/1.034880/1.034148. No historical hybrid or Toeplitz gains are added to
these numbers.

Exact-baseline-copy native controls have direct encrypt/decrypt ratios
0.998192/1.002397 and 0.997825/0.999253. Singleton baseline controls range from
0.992602 to 1.013036; isolated small differences are not treated as gains.
In particular the boundary subset's reversed singleton decrypt ratio 0.989270
is inconsistent with forward singleton ratios 1.009050/1.010591 and its direct
API results. The initial split singleton gains also fail to repeat.

All confirmation runs also measure actual `encryptBlocks`/`decryptBlocks`,
including singleton, every width 2..24, and 25/31/32/47/63/64/65/127/128/129/
255/256/257/1024/1025/4096/16384 blocks. These include matrix padding/copies,
Toeplitz preparation, boundaries and singleton tails. The unchanged native
2..24 controls have median-of-case ratios near parity; the spaced candidate's
first run has 1.009315/1.008126. Wider controls for that run reach aggregate
1.002861/1.011967; the other two runs are closer to parity. They do not rescue
the direct-call regressions. Every case, including noisy regressions, is in
`summary.json`, `confirmation.json`, and `confirmation-table.md`.

A separate generic x86_64-target run on the same Zen5 guest tests unchanged
portable paths, with 15 pairs and 131,072 target blocks/sample. Finalist direct
ratios range 0.990022..1.004659, versus portable baseline-control
1.006180/0.998846. These are unchanged-path controls, not portable speedups.
Only one portable seed is timed. All raw nanosecond arrays, checksums,
paired-ratio quantiles and per-offset medians are retained. `audit-data.py`
checks all 32 valid timing files: 1,328 cases and 34,704 measured paired
samples, including same-seed checksum equality across variants. Paired ratios are
never reconstructed from independent minima.

Median baseline direct latencies from the exact-baseline-control runs are:

baseline control seed | encrypt ns/block | decrypt ns/block
--- | ---: | ---:
94201 | 40.836346 | 44.335619
94202 | 42.351553 | 45.600933

These are descriptive medians, not independently selected minima or the basis
for the paired ratios above. Frequency/host variation remains visible.

## Search and implementation

Read the approved proposal/design/tasks and original hybrid source/history,
plus the original hybrid hypothesis evidence and operand-scheduling,
bitwise-normalization and feedback reports before starting. The earlier
count/group-count, encoded-state, VBMI S-box, coefficient-register and endpoint
constructor experiments are not repeated.

`screen.py` independently derives forward/inverse columns from the field
recurrence and verifies all 65,536 field products, 8,192 byte-basis products and
6,144 dense seeded mixed-column rounds. It explicitly checks the first inverse
round: GFNI uses F(x), while inverse-LUT indices use Pi(x), whose inverse
substitution cancels Pi. The final inverse endpoint is unchanged.

The analytical screen describes 4,368 possible five-position subsets by
extraction shape. It is deliberately descriptive: it does not assign a
reliable CPU cost or claim to discard every inferior subset. We compile only
16 structured families spanning prefix/suffix, each word, boundary bytes,
low/high mixes and spaced patterns. `exploration-table.md` lists every measured
candidate and regeneration/control result. `variants.json` records positions
and exact remaining-chain membership. `screen-codegen.csv` records all static
wrapper metrics. There are no new width/group-count tests: new evidence did
not warrant repeating previously rejected count variants.

`prepare.py` generates source-only snapshots from the pinned Git object. Only
`hybrid.zig` differs in candidates, with byte-position columns, matching byte
extraction and the ordered complement split by ordinal modulo three. All
assembly constraints, field conversion, defined vector lanes and inverse
endpoint code remain unchanged. The baseline's introductory “first five”
comment is inherited in experimental snapshots; their `selected` array is
authoritative. No benchmark-only production dispatch is added.

The exact regenerated prefix matches baseline wrapper instruction/stack counts.
The finalized scripts, raw sources and full assembly support reproducing all
rejections. Early harness/build mistakes, rejected before timing, are explicitly
recorded in `NOTES.md`; the invalid empty-input harness run is excluded from
all performance analysis.

## Assembly and footprint

Zig0.15.1 LLVM native exported full public-call wrappers on the owned Ryzen
9 9950X guest. Counts include every static instruction in all nine unrolled
rounds and endpoints.

| subset | encrypt instructions | decrypt instructions | encrypt stack accesses | decrypt stack accesses |
| --- | ---: | ---: | ---: | ---: |
| released prefix | 778 | 788 | 24 | 22 |
| boundary | 783 | 791 | 24 | 22 |
| split | 775 | 782 | 24 | 22 |
| spaced | 777 | 788 | 24 | 24 |

Each wrapper contains 54 GFNI instructions: 45 multiplications and nine inverse
affines. Stack counts include key/pointer storage, not only register spills.
Inspection finds entry-time GPR key/pointer storage and reloads, with no SIMD
round-state stack spills in these wrappers. There is no explicit `sub rsp`
allocation; red-zone and callee-saved-register storage remain. The spaced
inverse wrapper adds one stack store/reload pair. No candidate removes the
existing register-pressure storage.

The split wrapper shrinks code from 4,185/4,334 to 4,175/4,302 encrypt/decrypt
bytes, but loses in actual API timing. This is a concrete example of instruction
count failing as a latency predictor. `codegen.json`, `finalist-symbols.txt` and
the full assembly archive retain all details. Both full LUT objects remain
65,536 bytes per direction at identical relative object offsets (forward0x200,
inverse0x10400). The hot hybrid row selection remains 11*4,096=45,056 bytes
per direction for every subset; there is no static LUT-size reduction claim.

## Correctness and compatibility

Baseline and all three confirmed finalists pass the following exact matrix.
All 64 complete named suites were audited; totals are **4,772 passed test
entries and 64 expected skipped entries** across those repeated suites.

| configuration | pass / skip per variant |
| --- | ---: |
| native LLVM Debug, ReleaseSafe, ReleaseFast | 101 / 0 each |
| native private independent API/basis ReleaseFast | 102 / 0 |
| generic x86_64 LLVM Debug, ReleaseSafe, ReleaseFast | 93 / 2 each |
| native self-hosted Debug | 93 / 3 |
| znver4 ReleaseFast | 98 / 0 |
| znver5-gfni and znver5-avx512vbmi ReleaseFast | 93 / 3 each |
| znver5-avx512vl ReleaseFast | 100 / 1 |
| each of all 16 generated hybrid contribution suites | 8 / 0 |

Baseline and all three finalists also cross-compile for AArch64 Linux-musl
ReleaseFast. Column tests exhaust every byte value for selected forward,
inverse and raw-first-inverse contributions, plus inverse substitution endpoints.


An **extra synthetic AVX2-disabled diagnostic** on the exact unchanged baseline
(`zig test baseline/kuznechik.zig -OReleaseFast -mcpu=znver5-avx2 -fllvm`)
fails compilation with `couldn't allocate output register for constraint 'v'`.
It is not counted as a passing configuration. The initial runner stopped there;
finalist validation resumed under the profiles that the baseline supports.
`baseline-znver5-avx2.log`, `optional-feature-check.json`, the initial runner and
cache receipt preserve this limitation. It needs separate investigation beyond
the allowed hybrid-only production scope; no unrelated gate or kernel is fixed.


The private basic-reference test checks actual direct public APIs against
ordinary S/L/key transformations, including two fresh keys over all 16*256
single-byte values and 256 unrelated input blocks for each of 16 fresh keys.
Every arbitrary byte vector is also treated as independent valid ciphertext.
It checks Cipher=352 bytes. The runtime benchmark separately validates zero,
FF and fresh keys, lengths0..127, both directions, all four legal offsets and
complete guards, against independent single-block outputs before timing.
Every timed pair compares every output/guard byte; its final whole-buffer
checksum stays observable. No encryption-only or round-trip-only check is used.

All test runs use fresh unique disk-backed local/global caches. `audit.py`
verifies every sequential entry and actual test name, count and status, not
merely an executable exit status. `test-audit.json` retains the full name lists.
AArch64 logs establish successful compilation only, not runtime correctness
on AArch64. Source integrity checking compares every baseline production file
with the release object and permits only hybrid.zig differences in variants.

Delivered production source is unchanged. Thus Cipher fields and key values,
public APIs, all backend/target/model gates, memory and assembly contracts,
the24-block tail policy, non-Zen fallbacks and mode behavior remain exactly
released. No external prepared-key cache exists.

## Timing scope and reproduction

Owned exclusive Boat VM **bx_r9rh9mfv**, logicalCPU0 for timings. Compiler and
tests use CPU2 and never overlap timed runs. Short metadata/file-transfer calls
and normal VM services can occur; the physical host is not under our control.
The CLI creation JSONL, ownership receipt and hardware/compiler identities are
retained. No other VM is touched. Compiler archive and executable hashes match
the supplied hashes; full values are in hardware-compiler.log.

Cipher.init/key expansion, buffer reset, validation, hashing and printing are
outside timers. No allocations occur in timed calls. Public dispatch, encoded
key preparation when required, endpoints, transposition, padding and copies
are inside timing. Keys/inputs vary with runtime seeds. The source-only copies
contain no Git checkout or copied prepared keys.

On an otherwise idle compatible host, with Zig0.15.1 and a fresh disk-backed
stage:

```sh
export ZIG=/path/to/zig CACHE_ROOT=/disk/cache-root
bash docs/performance/2026-10-29/hybrid-positions/run.sh /disk/fresh-stage
cd /disk/fresh-stage
bash /repo/docs/performance/2026-10-29/hybrid-positions/confirm.sh
bash /repo/docs/performance/2026-10-29/hybrid-positions/validate.sh baseline boundary spaced split2
bash /repo/docs/performance/2026-10-29/hybrid-positions/validate-columns.sh
```

`analyze.py` and `summarize-confirm.py` reconstruct all tables from raw JSONL.
`chart.py` regenerates results.html. Exact measured source hashes and `measured-sources.tar.xz` identify corrected
timed inputs. `codegen.s.tar.xz` contains all full wrapper assembly files. The
archived validation script is the initial version that attempts the extra
AVX2-off diagnostic; the delivered validate.sh excludes that known failure. SHA256SUMS identifies all
retained evidence. Local portable and cross-compile commands are in
local-tests.sh and portable-candidates.sh.

## Limits, remaining hypotheses and cleanup

One virtualized Zen5 machine, one Zig/LLVM version, warm repeated workloads and
a finite structured subset sample cannot establish a physical optimum.
Executable placement, address/alignment, host scheduling/frequency and cache
working sets remain limitations. Reversed module placement and four legal
block offsets are controls, not exhaustive code/table address randomization.
Tiny individual differences within noise remain unresolved. Portable timing
uses one seed; AArch64 is compile-only. No security/constant-time proof is made.

Remaining hypotheses include other subsets among the unmeasured combinations,
orders within the five GFNI products, alternative complement-chain ordering,
and schedules informed by hardware counters or different compiler allocation.
They require new evidence; the current instruction-count reduction alone is
insufficient. No physical-optimality claim follows from retaining prefix5.

All evidence was preserved locally before deleting the owned VM. Boat deletion
operation `bdop_3766cb871f174a79a157bc0b05f870fe` reports **completed** for
`bx_r9rh9mfv` at `2026-10-29T12:26:11.524Z`. Both the request and final
status JSONL are retained. No other VM was accessed. No push, tag, release or
PR was created; root owns integration/publication.
