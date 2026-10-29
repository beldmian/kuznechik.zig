# Performance guide

The shipped implementation preserves the 352-byte `Cipher` layout, key schedule
fields and single-block APIs. `encryptBlocks` and `decryptBlocks` process in-place
slices of independent 16-byte-aligned blocks. Modes use byte slices and batch
independent work where their dependencies permit it.

## Selected paths

On the measured Zen 5 LLVM target, single-block operations combine five GFNI
byte-position contributions with eleven lookup rows and three integer reduction
chains. Large batches use a diagonally normalized Toeplitz circuit with 70 GFNI
maps per linear layer. Its inline assembly preserves required memory clobbers;
the rejected explicit-memory variants are not shipped. Small-batch matrix kernels
and padded internal tails cover shorter slices without writing past the input.

GFNI paths require LLVM and every declared target feature, including AVX2 and
the relevant AVX-512 features. Selection occurs at compile time. Other target
profiles and the self-hosted Debug backend use their supported fallbacks.
Portable batching interleaves independent table operations.

CBC encryption batches independent feedback entries for every IV width of at
least two blocks. Entry thresholds are 128 bytes for IV2, 48 bytes for IV3 and
64 bytes for other eligible widths. CFB batches power-of-two IV widths of at
least 64 blocks; OFB batches IV widths of at least 64 blocks. The usual one-block
feedback register retains its serial dependency. CCM processes full MAC blocks
directly; OCB bounds offset setup by actual message and AAD lengths.

## Evidence and limits

The [research index](performance/README.md) links exact sources, accepted and
rejected experiments, raw paired samples, assembly and validation receipts.
The final explicit-memory test was rejected and production remains v0.9.4.
Research ended at the user's request after that test. [Open issues](OPEN-WORK.md)
record remaining hypotheses and known short-call tradeoffs.

Results use Zig 0.15.1 on the recorded x86 guests. Dependent single-block latency,
independent-block throughput and complete mode calls are different workloads.
Key setup, cache state, message length, IV width and compiler affect results.
Do not combine ratios from different baselines or treat warm VM timings as a
physical performance bound. Native AArch64 execution remains future work.
The complete cipher and key expansion are not claimed constant-time.

## Reproduction

Build and test with Zig 0.15.1:

```sh
zig build test -Doptimize=ReleaseSafe -Dcpu=baseline
zig build test -Doptimize=ReleaseFast -Dcpu=native
zig build build_bench -Doptimize=ReleaseFast -Dcpu=native
taskset -c 0 zig-out/bin/benchmark \
  --api both --seed 123 --blocks 1048576 --samples 11 2> candidate.jsonl
python3 scripts/perf-compare.py baseline.jsonl candidate.jsonl
```

Capture baseline and candidate with identical compiler, target, backend, options,
runtime inputs and workload. The comparison script checks configuration and
output checksums. Use repeated paired measurements and unchanged controls for
small differences; `scripts/perf-pairs.zig` supports two imported source copies.
Historical experiment commands and their inputs are available together in the
archive. Extract it into a separate directory before using those paths. All
research VMs were deleted; their recorded identifiers must not be reused.
