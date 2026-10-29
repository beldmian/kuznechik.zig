Retained: bounded per-message OCB offset schedule, 2026-10-29

Starting point is released v0.9.0, main d42d82cd4ece09b6281aac58cdcbe6edef5d43b7. The retained implementation always computes L_star/L_dollar, then computes only bit_length(max(floor(AAD_bytes/16), floor(payload_bytes/16))) L_i entries. Empty and partial-only messages need none. The fixed 49-entry allocation-free storage and inclusive L48 endpoint remain. Both opening passes reuse this same schedule; validation, writable-alias rejection, read-only sharing, tag comparison and private plaintext verification before writes are unchanged. There is no new API.

On the exclusively assigned Boat bx_amh62u9b (AMD Ryzen 9 9950X / Zen 5, four vCPUs, 8 GB), Zig 0.15.1 ReleaseFast public seal/open measurements support retention. Positive numbers below are median paired wall-time reductions, including the common buffer reset and API setup. They are not independent-minimum comparisons or sums of separate experiments.

| Workload | Native seal | Native open | Portable seal | Portable open |
|---|---:|---:|---:|---:|
| Tiny 0/1/15/16/17-byte AAD × payload | 45.29% | 40.04% | 43.30% | 39.98% |
| 64 B–16 KiB records, AAD 0/16/17 | 22.60% | 15.86% | 9.22% | 4.32% |
| Independent AAD/payload power and batch boundaries | 17.42% | 11.79% | 5.74% | 4.38% |
| 1 MiB payload, AAD, or both | 0.54% | -0.05% | 0.00% | -0.21% |

The 89 workloads, two operations, seven alternating pairs, three seeds and forward/reverse/control layouts produce 22,428 paired rows in 18 complete CSV logs. Controls compare distinct byte-identical v0.9.0 modules. Native control individual paired reductions have p05/median/p95 -4.30/0.11/3.52%; portable controls -2.04/0.07/2.04%. Aggregate tiny per-case reductions are all positive; the smallest is 28.29%. The worst aggregate per-case result is native 1 MiB payload/no AAD open at -0.62%, versus its baseline control -0.82%. All aggregate per-case regressions are below 1%.

Small long-call costs are not ruled out: portable 1 MiB payload/17-byte AAD open has a -0.29% paired median, with all six seed/layout medians negative (-1.10% to -0.10%). This is a subpercent overall tradeoff, not evidence that every call improves. The initially observed native 16 KiB/no-AAD seal reverse-layout/seed7253 dip (-4.61%) is retained; that case has +3.68% aggregate reduction and other seed/layout medians up to +4.70%. No sample or layout was removed. Large calls are effectively close to baseline at this measurement precision. The sustained short-call and record gains, without a material aggregate long-call regression, justify retaining this one candidate. No second optimization or rejected implementation was measured; negative samples and all control evidence remain available.

The compiler did not already eliminate baseline setup in these actual runtime-sized public API calls: generated code retains the full fixed schedule initializer and its 816-byte copy. The bounded version inlines a length-dependent setup loop. See codegen.md for actual symbol addresses, both layouts, focused assembly and full compressed disassemblies. These observations do not characterize every possible statically sized caller.

Correctness was checked using fresh, distinct disk-backed local/global caches for every test configuration. check-logs.py checks every actual test entry/count and requires the named OCB tests in every unfiltered log. Results:

| Tree | Target | Build | Result |
|---|---|---|---|
| Exact v0.9.0 | native | ReleaseSafe | 99 passed |
| Exact v0.9.0 | x86_64 | ReleaseSafe | 91 passed, 2 GFNI skips |
| Candidate | native | Debug | 93 passed, 3 backend skips |
| Candidate | native | ReleaseSafe / ReleaseFast | 101 passed each |
| Candidate | x86_64 | Debug / ReleaseSafe / ReleaseFast | 93 passed, 2 GFNI skips each |
| Candidate | aarch64-linux baseline | ReleaseSafe | Complete test executable compiled and linked; not run |

Every candidate suite includes the existing 17 RFC7253 Appendix A tuples, nine aggregate checksums, 394 independent OpenSSL fixtures and 2208 guarded Kuznechik cases, together with all existing validation/alias/authentication-preservation tests. Two added named tests check the pure schedule length on both axes around every 2^0..2^48 endpoint and 280 independent AES-128-OCB boundary cases through 4097 full blocks, full/partial/empty inputs, nonce lengths 1..15 and representative 1/8/12/16-byte tags. Complete ciphertext SHA256, full tags, valid opens, failed-open whole-buffer preservation and guards are checked. Existing fixtures continue to cover every tag length. The new oracle uses Node v20.19.2 / OpenSSL 3.5.5 and regenerates byte-for-byte. No registered Kuznechik OCB interoperability is claimed.

The earlier local standalone ReleaseSafe log is labeled local-safe-initial.log. It predates the independent boundary test and is not substituted for any final full-tree test result. zig fmt --check, git diff --check, shell syntax checks and independent fixture regeneration also passed. The complete linked AArch64 executable was identified as an ARM aarch64 ELF; only its metadata/hash is retained, not a claim of execution.

Reproduction and evidence:

- method.md describes exact allocation/key setup/timing/validation boundaries, runtime input generation, calibration and limitations.
- bench.zig and run-vm.sh contain the exact measured driver and commands. run-vm.sh expects a complete `git archive <base> src` as /home/user/ocb/baseline.tar.gz and a source-only candidate tar containing src and this directory as source2.tar.gz, plus Zig extracted under /home/user. It builds six executables, runs the full correctness matrix, then times them sequentially pinned to core 0. finish-vm.sh performs the linked cross-compile and collects evidence after timing finishes.
- snapshots/baseline and snapshots/control are exact unchanged baseline modules; snapshots/candidate is the exact retained module. Executable-only test-import stubs accompany these snapshots. Actual tests use the complete trees.
- logs/run.log and logs/finish.log record commands; logs/test-*.log are the eight full suites; logs/aarch64*.log and aarch64-binary.txt record cross-compilation. test-results.txt verifies names/counts/skips.
- logs/bench-<target>-<layout>-<seed>.csv contain every sample and complete-output checksum. results.md and case-summary.csv are generated by analyze.py. comparison.html is generated by chart.py from those results.
- logs/source-manifest.sha256, baseline-source-manifest.sha256, driver-manifest.sha256 and binary-manifest.sha256 identify sources and built artifacts. verify-artifacts.py checks all 45 baseline source files against Git, all 46 candidate source files against this tree, and the measured benchmark/module snapshots. artifact-verification.txt contains the hashes. The collected evidence archive SHA256 is 3b50e1c5981700a34e103d835860746c44cd770d8ee04439c6dca257d76214e1; its complete contents are retained here under logs.
- logs/vm-setup.log records CPU, disk, kernel and both verified toolchain hashes. Archive SHA256 c61c5da6edeea14ca51ecd5e4520c6f4189ef5250383db33d01848293bfafe05; executable SHA256 0ee27482eb2e7b19fad58579c107364aa93fbfb54be2d2b9c52cef5f955d6225.

Limits: one shared-host Zen 5 VM and this Zig version, warm repeated calls, 24 runtime-generated keys across three seeds, 16-byte tags in performance measurements, eight final whole-output comparisons per sample rather than every intermediate timed call, and finite workload/layout coverage. Brief SSH status reads/completed-log transfers occurred during timing, but no compiler or test workload ran concurrently. Subpercent effects can mix layout, frequency, VM noise and real overhead; this is not a physical-optimality or security proof. Huge message limits are tested arithmetically without petabyte allocations. Existing caller obligations (unique nonces, aggregate key lifetime, stable inputs across opening passes) remain.

Cleanup: all evidence was transferred, archive hash matched and source/test/sample checks completed before deleting exclusively assigned bx_amh62u9b. Boat deletion bdop_cdb26188c3c84fa69a140d31fecf2ce2 completed at 2026-10-29 11:27:16.649 UTC, verified in logs/vm-deletion-status.json. No snapshots, other VMs, account secrets, pushes, tags, PRs or releases were used. Root owns integration/publication.
