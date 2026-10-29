## Context

The cipher currently fuses substitution and linear transforms in 64 KiB tables
per direction, with vector state and fully unrolled rounds. Optimization may
trade index extraction, dependent loads, cache footprint, XOR scheduling, and
code size. Table accesses already depend on secret state; this investigation
does not establish a constant-time implementation.

## Goals / Non-Goals

- Improve measured block latency and independent-block throughput in both directions.
- Retain byte-for-byte algorithm results and the existing public API.
- Avoid declaring a universal optimum from a finite set of VM measurements.
- Cipher modes, unrelated fuzzing changes, and new hardware requirements for the
  default portable implementation are outside this change.

## Decisions

- Pin experiments to Zig 0.15.1, matching the repository's documented toolchain.
- Measure long loops, warm caches, multiple samples, runtime data and output
  checksums; report latency and throughput separately.
- Keep a baseline copy and use identical benchmark code/compiler/CPU targets.
- Use parallel researchers for independent hypotheses; serialize timed runs on
  each benchmark CPU.
- Retain only changes that pass differential and known-vector checks, with
  performance conclusions scoped to actual tested hardware and build options.
- Preserve the original `Cipher` fields and key values. Key setup may reuse the
  same validated tables; initialization timing remains a separate metric.
- On measured Zen 5 targets, combine five GFNI byte-position contributions with
  eleven existing lookup rows, using three integer reduction chains. Keep the
  integer-only fallback for incomplete feature profiles. Define every lane of
  vector operands passed to inline assembly, including unused upper lanes.
- Keep GFNI/AVX-512 paths behind both target-feature and LLVM-backend checks.
  The Zig 0.15 self-hosted Debug backend retains portable code.
- Select batch tails using measurements of all lengths 1–63, including internal
  padding and copies. Reuse matrix kernels for 4/8/12/16/20/24 blocks and the
  byte-sliced 64-block kernel rather than maintaining a second narrow algorithm.
- On measured Zen 5 targets use a diagonally encoded Toeplitz circuit for
  64-block batches. Absorb row/column scales into fixed substitution tables and
  prepare encoded round keys once per call. Seed final output reductions with
  the next key. Keep the recurrence fallback for other CPU profiles. Record the
  earlier compensated-feedback key experiment separately.

## Risks / Trade-offs

- VM scheduling/frequency noise: use CPU affinity, repeated paired comparisons,
  machine metadata, and distributions rather than a single best observation.
- Compiler-specific code generation: inspect generated assembly and compare
  portable and native CPU targets.
- Larger tables/code can hurt cache behavior: measure both directions and
  independent workloads and report working-set assumptions.

## Migration Plan

No caller migration for the existing block API. Rejected experiments remain
outside production source; document enough detail to reproduce the conclusions.
