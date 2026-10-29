# Research archive

The investigation ended on 2026-10-29 at the user's request after the final
explicit GFNI memory-operand test. Production sources remain exactly v0.9.4.
Further hypotheses are tracked in [open work](../OPEN-WORK.md).

All tracked research files, source snapshots, raw samples, generators, compiler
output, validation logs and independent reviews are preserved in the
[research release](https://github.com/beldmian/kuznechik.zig/releases/tag/research-2026-10-29) and its [complete archive](https://github.com/beldmian/kuznechik.zig/releases/download/research-2026-10-29/kuznechik-research-2026-10-29.tar.gz).
Git history was preserved. Extract the archive into a separate directory to
use historical reproduction commands and paths.

- Snapshot: `b2dd7b6366e505b6b9e09b6865d0615e15261053`.
- Archive SHA-256: `52f8a3955b6c64d028c4f454755b3afc6d3f47e4e0253bccf85459079d102e0d`.
- The uploaded archive was downloaded and its SHA-256 verified before cleanup.
- Compiler, CPU, backend, input size and baseline belong to each individual report.

Selected retained changes:

- [Initial block kernels](https://github.com/beldmian/kuznechik.zig/blob/research-2026-10-29/docs/PERFORMANCE.md) and [original comparisons](https://github.com/beldmian/kuznechik.zig/blob/research-2026-10-29/docs/performance/RESULTS.md).
- [70-map GFNI normalization](https://github.com/beldmian/kuznechik.zig/blob/research-2026-10-29/docs/performance/2026-10-29/bitwise-normalization/RESULTS.md) and [operand selection](https://github.com/beldmian/kuznechik.zig/blob/research-2026-10-29/docs/performance/2026-10-29/operand-scheduling/RESULTS.md).
- [CCM full-block processing](https://github.com/beldmian/kuznechik.zig/blob/research-2026-10-29/docs/performance/2026-10-29/ccm-full-block/RESULTS.md).
- [Bounded OCB setup](https://github.com/beldmian/kuznechik.zig/blob/research-2026-10-29/docs/performance/2026-10-29/ocb-schedule/report.md).
- [OFB batching](https://github.com/beldmian/kuznechik.zig/blob/research-2026-10-29/docs/performance/2026-10-29/ofb-core70-integration/README.md).
- [Large feedback registers](https://github.com/beldmian/kuznechik.zig/blob/research-2026-10-29/docs/performance/2026-10-29/feedback-batching/RESULTS.md), [medium CBC registers](https://github.com/beldmian/kuznechik.zig/blob/research-2026-10-29/docs/performance/2026-10-29/medium-feedback/RESULTS.md) and [remaining CBC widths](https://github.com/beldmian/kuznechik.zig/blob/research-2026-10-29/docs/performance/2026-10-29/cbc-remaining-widths/RESULTS.md).

Recent rejected experiments:

- [Hybrid byte-position choices](https://github.com/beldmian/kuznechik.zig/blob/research-2026-10-29/docs/performance/2026-10-29/hybrid-positions/RESULTS.md).
- [GFNI graph scheduling](https://github.com/beldmian/kuznechik.zig/blob/research-2026-10-29/docs/performance/2026-10-29/gfni-pressure-scheduling/RESULTS.md).
- [Dedicated two-block GFNI kernel](https://github.com/beldmian/kuznechik.zig/blob/research-2026-10-29/docs/performance/2026-10-29/gfni-pair/REPORT.md).
- [Explicit constant-memory operands, the final experiment](https://github.com/beldmian/kuznechik.zig/blob/research-2026-10-29/docs/performance/2026-10-29/gfni-memory-operands/RESULTS.md).

These are finite measurements on the recorded guests and compilers. They do
not establish a physical optimum or a speed improvement for every caller.
The [current performance guide](../PERFORMANCE.md) describes the shipped paths.
