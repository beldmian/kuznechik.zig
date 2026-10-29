# v0.9.4 integration receipt

Root integrates author commit `527f0994f17d4a320c577338063a30e2cd70f721`
over released v0.9.3. The production diff replaces CBC's medium-width whitelist
with `iv_blocks >= 2`. Its existing batch loop, thresholds, scalar/decryption
paths, contexts and all other modes/kernels remain unchanged.

## Review and scope

Each group remains bounded by the IV width and reads distinct feedback entries
before replacement. Therefore enabling another width cannot introduce a
within-group ciphertext dependency. Scratch remains bounded to min(64, IV
blocks), and length validation still precedes writes. The two added tests
exercise every newly eligible width through independent AES/Kuznechik physical
shift-register references, alignments, ring/group boundaries, mixed directions,
exact context fields and atomic rejection. Root found no blocking source issue.

Root ran the author verifier and full evidence checksum inventory against the
integrated source. These bind the exact v0.9.3 baseline and allowed source diff
to the complete source bundle, remote hashes, 42,200 raw final/control rows,
379,800 measured pairs, 14 sequential named test receipts, linked AArch64
build and completed author-VM deletion. Every newly eligible width has actual
measurements; the changed predicate is not an extrapolation from sampled widths.

The [performance report](../../performance/2026-10-29/cbc-remaining-widths/RESULTS.md)
records substantial batched gains and small repeatable short-call costs,
including approximately 1.7% for native IV18 split16 and 1.5% for portable
IV27 whole48. Root retains this throughput tradeoff without asserting that
every call improves. The 16 KiB ranges are measured against exact v0.9.3 on
the recorded Ryzen 7 9700X guest and Zig 0.15.1; gains from other investigations
are not combined.

## Integration verification

Two author local full-suite compilation attempts were killed before test
execution. Their focused local checks passed 7/7, while all full VM suites
passed. Root uses a fresh large Boat VM, `bx_nej7mh8w`, for its full native
ReleaseSafe/ReleaseFast, portable ReleaseSafe and standard build checks rather
than repeating the killed local compiles. These root checks use isolated
disk-backed caches, verify actual named inventories, and require both new
width tests plus the existing feedback and OCB tests.

`checks.json` records configurations, exits, test names and counts. Compiler/
CPU identity, source manifests, full logs and completed cleanup receipts are
retained here. `source-sha256.json` must match both the remote tree and the
author candidate for library source. Version/changelog changes are metadata.
Author receipts additionally cover LLVM Debug, portable Debug/Fast, three
negative-feature profiles, linked AArch64 compilation, and 8/8 layout/state
drivers. Compile-only cross-target evidence is not described as execution.

Final root results: **105/105 native tests** in ReleaseSafe and ReleaseFast;
**97 portable passes with two expected skips**, 99 entries; and the standard
portable ReleaseSafe build test succeeds. The larger integration VM avoids
repeating the killed local compiles. Selected short-cost and large-call ratios
were independently recomputed across all five raw runs and match the report;
`selected-raw-ratio-checks.json` records those checks.

These are finite correctness and warm-workload measurements. Physical
optimality, cold-cache behavior and universal caller/compiler improvements
remain unproven. The separate two-block-kernel and graph-scheduling experiments
are not part of this release.
