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
