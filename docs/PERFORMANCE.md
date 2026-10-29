# Block cipher performance investigation

The optimization preserves `Cipher`, its key schedule and single-block API, and
adds in-place `encryptBlocks` / `decryptBlocks` for independent raw blocks.
Measurements distinguish dependent single-block latency from independent-block
throughput. Batch throughput improvements do not apply to a serial cipher mode.

## Measurement setup

- Reference compiler: Zig 0.15.1, `ReleaseFast`, native CPU target.
- Baseline: the four original `src/*.zig` files from commit
  `5a4e3b0`, compiled with the same new benchmark and build options.
- Boat CLI provisioned isolated Linux VMs for parallel experiments and separate
  comparisons. Ryzen 9 9950X hosts and a Ryzen 7 9700X host were available;
  the local Intel Xeon E5-2690 v4 supplied a Broadwell comparison.
- Final comparison workloads use a runtime seed, warmup, CPU affinity, repeated
  long samples, fractional nanoseconds/block, and output checksums. Key setup,
  data preparation, statistics, and checksums are outside the measured loop.
- Width 1 is a dependent chain. Larger widths contain independent chains.
  The original source lacks batch methods, so the identical benchmark falls
  back to its single-block API when measuring the baseline's `bulk` workloads.
- JSONL records include compiler version, CPU model, effective feature masks,
  backend, optimization mode, input seed, sample counts, checksums, and raw elapsed times.
  The comparison script rejects mismatched configurations or outputs.

VM clock rates and scheduling vary. Small scheduling changes were tested using
alternating baseline/candidate samples in one process. Absolute times must be
interpreted together with their CPU/profile and raw samples, not as universal
machine-independent constants. Cache/PMU topology reported by a VM is not a
substitute for physical-host topology.

## Results and evidence

See the [recorded comparison tables](performance/RESULTS.md) and
[interactive chart](performance/results.html). Comparison records, machine metadata, hardware counter receipts, and the
exploratory compiler comparison are in [performance/2026-10-29](performance/2026-10-29/).
The table and SIMD hypothesis receipts are in
[hypotheses-table.json](performance/hypotheses-table.json) and
[hypotheses-simd.json](performance/hypotheses-simd.json).
The single-block hybrid has separate
[encryption](performance/hypotheses-hybrid-encrypt.json) and
[decryption](performance/hypotheses-hybrid-decrypt.json) receipts.

The final three Ryzen 9 9950X comparisons measured 1.53–1.87× encryption and
1.54–1.95× decryption speedups for dependent single-block chains. Independent
256-block batches measured 15.22–18.69× and 17.84–21.38× respectively. These
ranges retain host variation; the tables show every profile separately.
The final hybrid was not benchmarked on the earlier 9700X VM; that host supplied
component and tail-strategy validation. Earlier scalar-path comparisons are
preserved in the `scalar-checkpoint` subdirectory.

The summary tables and interactive comparison accompany the final recorded runs.
All performance ratios compare the same operation, API workload, input, compiler,
CPU target, block count, and sample count.
The [source and binary manifest](performance/2026-10-29/manifest.json),
[validation record](performance/2026-10-29/validation.json), and
[integration review](performance/integration-review.json) identify the final
implementation and its checks.

A supplemental 128 MiB streaming experiment measured 3.484 ns/block encryption
and 3.516 ns/block decryption, versus 59.867 and 68.270 for the original loop:
17.18× and 19.42×. Every output byte matched. Initialization, buffer preparation,
and full comparisons were outside timing. Its [raw receipt](performance/2026-10-29/streaming.json)
records the exact source snapshot; subsequent key-setup and tail changes do not
alter the full 64-block kernel. This is distinct from the warmed small-buffer
benchmark and its separate machine profiles.

## Selected implementations

### Single blocks

On the measured Zen 5 target, the fastest tested LLVM path combines integer
lookup chains with SIMD arithmetic. It computes the first five byte-position
contributions using 128-bit GFNI products, then converts their aggregate back to
Kuznechik's field. The other eleven contributions reuse the original lookup
table, leaving 44 KiB of lookup rows active per direction. No large table is
duplicated. Three short integer chains overlap the SIMD work, keep inter-round
state in integer registers, and incorporate the next key before reduction.

Decryption fuses the initial S directly into first-round indices and uses a
VBMI register lookup for the final inverse S. All vector operands passed through
inline assembly are defined, including unused upper index lanes. The original
all-integer Zen 5 kernel remains the fallback when the hybrid's LLVM/GFNI/AVX2
and AVX-512 requirements are not enabled. Its empty register constraints preserve
short XOR chains through LLVM reassociation without emitting instructions.

The hot-row footprint reduction is exact, but VM cache counters were not reliable
enough to attribute the entire gain to cache behavior. Paired measurements and
retired cycle/instruction counters establish the actual performance change.

On Broadwell, the all-scalar schedule regressed. Its encryption path instead
extracts indices in integer registers and reduces two independent SIMD chains.
Decryption retains the original vector schedule. These choices are selected for
the measured CPU model names; other models retain the portable single-block
implementation.

### Independent blocks

The portable batch implementation interleaves independent table lookups by
round. GFNI-capable builds additionally use:

- A small-batch matrix kernel: map Kuznechik's byte field to GFNI's AES field,
  substitute through register permutations, and evaluate cyclic diagonals of L
  using GFNI products and lane-local rotations. Eight-block decryption uses
  independent reduction trees; other widths share coefficient scheduling.
- A 64-block byte-sliced kernel: transpose blocks into sixteen byte-position
  vectors. The transpose works separately in each 128-bit lane, retaining a
  harmless block permutation that its inverse removes. Encode each constant
  multiplication directly as a GFNI affine map in Kuznechik's original field.

Every remainder size 1–63 was measured with zero filling and copies inside the
timed section. A single matrix kernel rounded to a multiple of four handles
2–24 blocks; 25–63 blocks use a padded 64-block kernel. Exact sizes avoid the
copies, and a lone block uses the single-block method. Padding is internal;
only the requested blocks are copied back. A separate 32-block YMM recurrence
was correct but offered no convincing advantage over padding the existing
64-block kernel, so its extra implementation was not retained.

The R coefficients contain symmetric pairs and satisfy
`148 = 133 ^ 16 ^ 1`. The selected recurrence isolates the newest feedback in
one `148` multiplication, folds the independent partner into the `133` and `16`
products using that identity, and ends with one XOR. This retains seven GFNI
operations while shortening the serial feedback dependency. Pure register
constraints for computed ternary-XOR and transpose inputs avoid stack traffic.
Round-key bytes are broadcast directly.

GFNI kernels require all enabled target features, including GFNI, AVX-512 F/BW,
VBMI, and Zig 0.15.1's `evex512` compiler feature. The latter prevents a backend
failure for manually constructed incomplete feature profiles. Kernel selection
is static; portable binaries do not perform runtime dispatch.
The accelerated kernels also require the LLVM backend: Zig 0.15's default
self-hosted x86 Debug backend lacks their AVX-512 register constraints and uses
the portable path instead. `zig test src/kuznechik.zig -O Debug -fllvm` explicitly
exercises accelerated Debug code on a capable host.

Table generation now computes eight binary basis contributions per byte rather
than evaluating full L for each of 256 entries. This reduces full compile-time L
evaluations from 8192 to 256 for both tables together, with identical table data.

Key setup separately reuses the existing LS tables for Feistel updates and
inverse-key generation. All ten forward and inverse keys match basic transforms.
Paired initialization-only experiments measured about 163 microseconds versus
0.44 microseconds on one VM; initialization remains outside block timings.

Build support accepts explicit optimization modes and the prior release flags.
The benchmark module is private, so it no longer overwrites the exported
library module. A separate local dependency consumer verifies both existing and
batch APIs; this export fix leaves the benchmark executable byte-identical.

For long buffers on the measured Zen 5 target, compensated feedback keys fuse
round-key XORs into existing ternary-XOR operations. The compensation accounts
for previously keyed feedback values, so all sixteen steps still produce the
required linear output plus key. Preparation handles four round keys per vector
and is amortized over a public call of at least 512 blocks. `Cipher` keeps its
original fields. Two-host paired tests include preparation; the
[receipt](performance/2026-10-29/continuation-1/key-injection.json) also records the
slower final-feedback seeding variant. Full API comparisons cover the threshold
and tails, with every output compared after each sample.

## Rejected approaches

The receipts record both wins and regressions. Important rejected candidates:

- Split scalar tables and scalar state on Broadwell: substantial regressions.
- Compact nibble tables: lower footprint did not offset extra work.
- Fused 16-bit lookup tables (1–8 MiB): memory cost outweighed fewer lookups.
- AVX-512 gathers for single blocks: slower than scalar indexing.
- A separate first inverse-L table: extra table did not improve decryption.
- Fully unrolling nine vector cipher rounds: significantly slower.
- Six-product R formulas: mathematically correct, but longer feedback paths and
  worse scheduling outweighed the instruction saving.
- Eight-product feedback splitting: faster than the initial recurrence, but
  slower than the seven-product algebraic split with the final XOR.
- Extra ternary-XOR rearrangements: no consistent further gain.
- Prepared 640-byte expanded round keys and fused memory-broadcast XOR: correct,
  but inconsistent 0–1% differences, so the extra representation was rejected.
- AES-field byte slicing: no advantage over direct affine multiplications.
- Keeping the hybrid round state in the AES field, replacing its byte lookups
  with a whole-vector S-box, and processing most positions arithmetically:
  slower than the selected five-column mix in the measured configurations.

Zig 0.15.2 and an experimental, privately ported 0.17.0 version were sampled with
an earlier kernel. They did not establish a consistent advantage across both
directions. The 0.17 experiment required language/API changes and is not a claim
that the delivered repository supports that compiler. These exploratory records
are separate from final before/after comparisons.

## Correctness and portability

Checks include the RFC vector, independent basic-transform comparisons for
arbitrary plaintext and ciphertext, every lookup-table contribution, all byte
field products, every substitution byte, every binary basis vector for both
linear directions, transpose mapping/inversion, and batch boundaries through
1025 blocks. Guard comparisons cover memory outside requested slices and all
four alignments modulo 64 allowed by the 16-byte API contract.

Run Debug, ReleaseSafe, and ReleaseFast tests on native and portable targets.
Instruction-specific tests explicitly skip when their required features are not
enabled. Cross-compilation checks cover AArch64, big-endian PowerPC64, and Wasm;
these are compilation checks, not runtime validation on those machines. Existing
standalone fuzz harness smoke checks remain separate from sustained fuzzing.

The table paths and key expansion retain secret-dependent memory accesses. This
work does not establish constant-time behavior for the complete cipher API.

## Reproduce

```bash
zig build test -Doptimize=Debug
zig build test -Doptimize=ReleaseSafe
zig build test -Doptimize=ReleaseFast
zig build fuzz-test
zig build build_bench -Doptimize=ReleaseFast -Dcpu=native
taskset -c 0 zig-out/bin/benchmark \
  --api both --seed 123 --blocks 1048576 --samples 11 2> candidate.jsonl
python3 scripts/perf-compare.py baseline.jsonl candidate.jsonl
python3 scripts/perf-report.py docs/performance/2026-10-29
```

For small incremental changes and long buffers, compare two source trees in one
process with alternating order. Set `BASELINE_TREE` to a saved source tree:

```bash
zig build-exe --dep baseline --dep candidate \
  -O ReleaseFast -mcpu=native -Mroot=scripts/perf-pairs.zig \
  -O ReleaseFast -mcpu=native -Mbaseline="$BASELINE_TREE/src/kuznechik.zig" \
  -O ReleaseFast -mcpu=native -Mcandidate=src/kuznechik.zig \
  -femit-bin=perf-pairs
taskset -c 0 ./perf-pairs 123 2> paired.jsonl
```

This driver measures both public batch methods at 64–8,388,608 blocks, includes
all per-call preparation, checks every output after each alternating pair, and
records 31 raw pairs per case. Buffer resets, comparisons, key initialization,
and checksums are outside timing. Its incremental baseline is separate from the
original-source comparisons above.

To reconstruct the baseline, copy the current `build.zig`, `build.zig.zon`, and
`test/benchmarks.zig` into a temporary directory. Put the original
`kuznechik.zig`, `definitions.zig`, `transitions.zig`, and `luts.zig` under its
`src/` directory using `git show 5a4e3b0:src/<file>`. Build and run with the same
commands, CPU target, seed, counts, and affinity. Do not compare optimized code
to a Debug baseline.

Boat provisioning used `boat new --no-env --no-snapshots --ttl 7200`, followed
by `boat scp` / `boat push` and `boat ssh`. Toolchain downloads were verified
against Zig's published SHA-256 checksums. Tests require no account secrets on
the VMs. The seven machines from the first pass were deleted or expired after
evidence was collected; its [cleanup receipt](performance/2026-10-29/cleanup.json)
confirms that none remained at that checkpoint. Later passes record their own
resources and cleanup separately. Other account resources were left alone.

## Performance limits

The selected 64-block formula executes `7 * 16 * 9 / 64 = 15.75` GFNI operations
per block. A hardware-counter microbenchmark on one Boat VM sustained about two
independent GFNI operations per core cycle, giving a GFNI-only resource floor
of 7.875 cycles/block for this formula. The feedback chain supplies a separate
dependency constraint. These constraints overlap; they must not be added as if
they were independent elapsed times. Substitution, keys, transposes, loads,
register scheduling, and loop overhead still contribute to measured time.

This bounds a particular implementation model on tested hardware. It is not a
proof of a physical optimum. Other algorithms, CPU families, compiler versions,
workloads, and hardware implementations may improve further. Finite benchmarks
can establish measured wins and rejected hypotheses, not impossibility of all
future improvements.
