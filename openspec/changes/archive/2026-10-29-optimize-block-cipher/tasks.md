## 1. Measurement

- [x] 1.1 Install the repository-compatible Zig toolchain and verify baseline tests.
- [x] 1.2 Implement reproducible encryption/decryption latency and throughput benchmarks.
- [x] 1.3 Provision Boat VMs and record CPU/compiler/baseline measurements.

## 2. Optimization

- [x] 2.1 Test independent hypotheses in parallel and record results.
- [x] 2.2 Implement measured improvements while preserving the existing API.
- [x] 2.3 Add differential correctness checks against the basic transformations.

## 3. Verification

- [x] 3.1 Run correctness checks in Debug, ReleaseSafe, and ReleaseFast.
- [x] 3.2 Compare baseline and optimized implementations on Boat VMs.
- [x] 3.3 Document reproducible results, remaining hypotheses, and resource cleanup.

## 4. Continued investigation

- [x] 4.1 Derive and validate alternative factored linear circuits.
- [x] 4.2 Measure compensated feedback-key injection, including preparation cost.
- [x] 4.3 Measure alternative position subsets for the hybrid single-block path.
- [x] 4.4 Integrate further verified wins or record rejections and clean up new resources.

## Closeout — 2026-10-29

The user ended investigation after the explicit-memory GFNI test. Continued
work above produced the normalized 70-map circuit, compensated-key measurements,
hybrid-position rejections, and final schedule/pair/memory-operand rejections.
The [research archive](../../../../docs/performance/README.md) preserves exact
reports, sources, raw samples and validation. Completing these finite experiments
does not establish physical optimality. Remaining hypotheses and feedback costs
are tracked in [#9](https://github.com/beldmian/kuznechik.zig/issues/9) and
[#5](https://github.com/beldmian/kuznechik.zig/issues/5); no additional tests or
VMs are scheduled.
