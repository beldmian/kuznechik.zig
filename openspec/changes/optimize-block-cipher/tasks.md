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

- [ ] 4.1 Derive and validate alternative factored linear circuits.
- [ ] 4.2 Measure compensated feedback-key injection, including preparation cost.
- [ ] 4.3 Measure alternative position subsets for the hybrid single-block path.
- [ ] 4.4 Integrate further verified wins or record rejections and clean up new resources.
