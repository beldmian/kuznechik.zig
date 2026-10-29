# Change: Optimize block encryption and decryption

## Why

The user requested an aggressive, measured search for faster block operations,
including parallel hypothesis testing and performance tests on Boat VMs. The
existing benchmark omits decryption and cannot distinguish single-block latency
from independent-block throughput.

## What Changes

- Establish reproducible latency and throughput benchmarks with observable output.
- Compare table layout, byte extraction, round scheduling, and SIMD hypotheses.
- Adopt improvements supported by correctness tests and repeated measurements.
- Preserve the existing block API, ciphertexts, key schedule, and portable build.
- Add optional in-place `encryptBlocks` / `decryptBlocks` APIs for independent
  raw blocks, selecting feature-gated GFNI/VBMI or portable interleaved kernels.
- Record machine details, rejected hypotheses, and limits of the evidence.

## Impact

- Affected specs: block-cipher-performance (new).
- Affected code: `src/kuznechik.zig`, `src/luts.zig`, benchmark/build support.
- Authorization: the user's explicit request to start and persist with this
  optimization is the implementation authorization for this investigation.
