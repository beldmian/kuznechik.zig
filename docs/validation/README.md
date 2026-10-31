# Validation records

The [closeout receipt](closeout.json) pins every source file to the unchanged
v0.9.4 production tree and records root's independent audit of the final test.
The complete [historical receipts](https://github.com/beldmian/kuznechik.zig/tree/research-2026-10-29/docs/validation) and
[downloadable research archive](../performance/README.md) retain all logs.

Final experiment checks covered 39 complete named runtime logs: 3,297 passes
and 54 expected skips across baseline and two candidates. Each native LLVM
Debug/ReleaseSafe/ReleaseFast suite passed 105 tests. Portable suites passed
97 tests with two expected skips. Backend/feature profiles, independent algebra
and product tests, and three linked AArch64 builds also passed.

Root reread and hashed all 302 VM archive members, verified source identities,
named test inventories, paired sample checksums and generated code, and reproduced
the delivered audit summaries. Both candidates were rejected. See the
[final report](https://github.com/beldmian/kuznechik.zig/blob/research-2026-10-29/docs/performance/2026-10-29/gfni-memory-operands/RESULTS.md)
and [v0.9.4 integration receipt](https://github.com/beldmian/kuznechik.zig/blob/research-2026-10-29/docs/validation/v0.9.4/README.md).

All Boat VMs, including stopped VMs, were deleted. The all-state list was empty
at closeout. Cross-compilation is not runtime validation: native AArch64,
broader CI and build-memory coverage remain [issue #6](https://github.com/beldmian/kuznechik.zig/issues/6).

The two text files in `mgm-profiles/` are retained inputs for
`src/modes/mgm_profiles_reference.py`. They are RFC 9367 and RFC 9227 source
snapshots used to regenerate the checked-in fixture; other research data is
available from the archive. Ordinary library tests use checked-in fixtures.

## Local follow-up, 2026-10-30

On Linux x86-64, Intel Xeon E5-2690 v4, Zig 0.15.2, the command
`zig build test -Doptimize=ReleaseSafe -j1` completed successfully in 198.76 s;
`getrusage(RUSAGE_CHILDREN)` reported a maximum child RSS of 763,584 KiB. The
existing Zig caches were used; this is not an isolated-cache build measurement.
The user-facing `test` build step was run once; its quiet output does not retain
an individual named inventory. This result does not establish AArch64 execution
or any other backend/feature combination.

`scripts/validate-matrix.py` can run individual full-suite profiles in fresh,
per-profile local and global caches, preserving the named Zig test log, compiler
identity, host CPU details, elapsed time, exit code and maximum child RSS. It
exits nonzero on any requested profile failure. Its default matrix includes
portable and native LLVM Debug/ReleaseSafe/ReleaseFast, native self-hosted Debug,
and native x86 feature-disabled profiles. It must run on the intended native
host; disabling a feature is not a substitute for executing on another CPU.
No CI service or native AArch64 run is implied by providing this runner.

An isolated-cache `baseline-releasesafe` run through the new matrix runner was
also attempted on this host. After 407.75 s the compiler was terminated by
signal 9; the log contained no diagnostic and the recorded peak child RSS was
746,792 KiB. The reason for termination is unconfirmed. This failed attempt is
not a passing portable profile or a complete test inventory. The GitHub Actions
workflow is present locally but has not run.

## Boat x86-64 matrix, 2026-10-30

A Boat large VM (8 vCPU, 16 GiB, AMD Ryzen 9 9950X) ran Zig 0.15.2 with
fresh local and global caches per profile using `scripts/validate-matrix.py`.
The copied `src/kuznechik.zig` SHA-256 was
`6e5b2b61f38dbab46d69d316131a9e860522f233c07a5dead5d93ac66f31d0d2`;
the runner hash was `dbc753cb94dff2fc5c0b3fd3410cdfe775b2a08463b64a83e3f6c2e46fce0ec1`.
All 11 profiles exited successfully. The full named test inventories, host CPU
features, resource metrics and checksums are in [boat-x86-2026-10-30](boat-x86-2026-10-30/).

| Profile | Passed | Skipped | Peak child RSS KiB |
|---|---:|---:|---:|
| baseline LLVM Debug | 97 | 2 | 903472 |
| baseline LLVM ReleaseSafe | 97 | 2 | 922888 |
| baseline LLVM ReleaseFast | 97 | 2 | 816092 |
| native LLVM Debug | 105 | 0 | 951800 |
| native LLVM ReleaseSafe | 105 | 0 | 913104 |
| native LLVM ReleaseFast | 105 | 0 | 885660 |
| native self-hosted Debug | 97 | 3 | 384216 |
| native without GFNI | 97 | 3 | 837572 |
| native without AVX512 VBMI | 97 | 3 | 869944 |
| native without AVX512 VL | 104 | 1 | 886332 |
| native without AVX2 | 97 | 3 | 851492 |

Feature-disabled builds use LLVM ReleaseFast. Skip names are recorded in the
logs; they reflect backend and feature gates. The synthetic AVX2-disabled run
exercises the fallback on this host. This is correctness evidence for the stated
compiler and VM CPU, not a performance comparison or proof for other hardware.
Native AArch64 and an actual GitHub Actions execution remain unverified.


## Publication follow-up, 2026-10-31

The matrix runner now verifies every numbered test against the final summary
and writes a machine-readable inventory. Truncated logs or missing test entries
fail the profile even when the executable returns zero. New runs also preserve
source hashes and the exact command/cache paths. Parser regressions validate all
11 preserved Boat logs and reject missing entries and inconsistent summaries.
The historical Boat records above remain unchanged and refer to the recorded
runner hash; the portable self-hosted profile was added afterward for CI.

The checked-in workflow pins official Zig archive hashes and action commits,
runs the shell/Python harness regressions, and schedules native x86-64 and
AArch64 jobs. Its syntax passed actionlint locally. Native AArch64 execution
must be established by those job results; local cross-linking of the scalar
reference with self-hosted AArch64 Debug is compile-only evidence.

Boat VM `bx_7v565qqk` was deleted after all raw logs and their checksums were
copied and verified. Deletion operation
`bdop_19f98e00c0bf4116b9520f1253ca0737` completed at
`2026-10-30T14:04:06.699Z`; the subsequent all-state VM list was empty. The
last usage receipt before deletion was $0.02471 (20m36s wall time), within the
approved $0.10 budget. No new VM is authorized or needed for publication.
