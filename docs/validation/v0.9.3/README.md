# v0.9.3 integration receipt

Root integrates medium CBC author commit
`1f82cbaf29678c9539b08a57eb081982f0f1c53d` over released v0.9.2 and fixes
the LLVM GFNI feature gate. The hybrid-position investigation is retained as
rejection evidence; its production source remains unchanged.

## CBC review and measured scope

The production change adds the measured medium-register selector and entry
thresholds, and bounds helper scratch to min(64, IV blocks). Each batch still
reads distinct register entries before replacement; its size cannot exceed
the register width. IV3's 48-byte loop step always consumes three complete
blocks. IV2 enters at 128 bytes, loops while at least 64 bytes remain, and
finishes the remaining complete blocks through the scalar path. Length
validation still precedes all writes, and no context field or API changes.
Root review found no blocking issue.

The exact integrated classic module matches the author's retained snapshot.
All candidate Zig files match the source bundle except the separate root
GFNI gate fix. Root ran the author's verifier and complete evidence checksum
inventory in the author tree before integration. That verifier validates
the exact released baseline, archived sources, final VM source binding,
58,752 main measured pairs, additional controls, 13 validation receipts,
linked AArch64 compilation and completed benchmark-VM deletion.

The [CBC results](../../performance/2026-10-29/medium-feedback/RESULTS.md)
compare exact v0.9.2 on the recorded Zen 5 guest/compiler. They include context
initialization and input copying, and exclude allocation and key expansion.
CFB candidates are rejected, rather than included for their large-call gains.
Unlisted medium widths remain scalar. These measurements are not combined
with older isolated gains or extrapolated to every CPU/width.

## AVX2-disabled target

Root reproduced `zig test src/kuznechik.zig -O ReleaseFast
-mcpu=znver5-avx2 -fllvm --test-no-exec` failing on the unchanged source with
`couldn't allocate output register for constraint 'v'`. This synthetic target
still reports the AVX-512/GFNI features needed by the old gate, but Zig 0.15.1
LLVM cannot allocate those vector operands without AVX2.

The gate now also requires AVX2, matching the compiler's usable vector profile.
The same target compiles through the fallback after this one-feature change.
The pre-CBC compile-only regression and its successful gate-only counterpart
are recorded separately; they are not presented as runtime tests.
The final combined suite additionally executes that synthetic target on the
capable Boat guest. Normal native targets with AVX2 retain accelerated dispatch.

## Combined checks and cleanup

Root runs the combined source in native ReleaseSafe/ReleaseFast and synthetic
AVX2-disabled ReleaseFast on exclusive Boat VM `bx_w7s4nk26`, and portable
ReleaseSafe plus the standard build test locally. `checks.json` records exits,
actual named test inventories and the source-manifest comparison. All suites
must contain both independent feedback tests and both OCB schedule tests.
Compiler/CPU identity, exact source hashes, logs and cleanup receipts are kept
here. Version/changelog edits do not change those library sources.

The source archive and author validation also cover LLVM Debug, portable
Debug/Fast, additional feature gates, linked AArch64 builds, and 8/8 layout /
atomic-rejection and 8/8 direction-continuation driver checks. Those are author
receipts, separate from root's combined runs.

These finite tests and measurements do not establish physical optimality.
Other subsets, schedules, register widths and compiler choices remain open
research questions.
