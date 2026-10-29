# v0.9.2 combined integration receipt

Root integrates author feedback commit
`6e2f104b3e8b27ef76a844e21c74eac27d6af6a4` over released v0.9.1, preserving
that release's bounded OCB setup. The feedback measurements compare exact
v0.9.0 classic modes and cipher kernels; OCB is not involved in those timings.
Those results are not added to earlier gains or presented as a measured
comparison of the complete v0.9.1/v0.9.2 binaries.

## Source review

Each batch reads at most min(64, IV blocks, remaining full blocks) distinct
register entries before replacement. The ring cannot repeat within a group;
the next group's inputs therefore match sequential feedback processing.
The CBC length check remains before the dispatcher and all writes.
CFB first completes a pending segment, then handles full groups and scalar
tails. It preserves the scalar path's last stream and feedback bytes even
when used is 16, supporting later calls in either direction. Context fields,
layouts, Cipher size and APIs remain unchanged. Root found no blocking issue.

The measured CBC/CFB source matches the integrated module exactly.
`feedback-batching/verify.py` validates its archived sources, exact released
baseline, 2,016 benchmark cells / 18,144 measured pairs, test receipts and
evidence hashes. Its source archive retains the pre-OCB-optimization tree;
the new combined suite below is separate integration evidence.

## Combined verification

`checks.json` records actual test inventories, configurations and exit codes.
Root runs native ReleaseSafe/ReleaseFast on a fresh exclusive Boat VM and
portable Debug/ReleaseSafe plus the standard ReleaseSafe build test locally,
using fresh disk-backed caches. Every suite includes the existing cipher and
mode tests, both new feedback tests and both OCB schedule tests.
`source-sha256.json` binds the combined library source to the remote manifest.
Compiler identity, VM CPU details, logs and cleanup receipts are retained here.
Metadata-only version/changelog changes do not alter those library sources.

Native ReleaseSafe/ReleaseFast each pass **103/103 tests**. Portable
Debug/ReleaseSafe each pass **95 tests with two expected GFNI skips**
(97 entries). Both focused context checks pass their named test plus five
import-discovery tests, **6/6 each**. Root's VM is `bx_eprfj2f7`, an AMD
Ryzen 9 9950X guest; Zig 0.15.1 matches the recorded executable hash.

The independent feedback tests cover AES/Kuznechik shift-register references,
IV widths 1/2/3/63/64/65/128, all 16 alignments, pending CFB byte counts,
ring and batch boundaries, output guards, exact context fields, inverse output
and CBC atomic rejection. Author evidence additionally retains explicit LLVM
Debug, portable ReleaseFast, linked AArch64 builds, exact layout contracts and
randomized direction continuation against the baseline.

## Scope

See [results and reproduction](../../performance/2026-10-29/feedback-batching/RESULTS.md)
and [rejected experiments](../../performance/2026-10-29/feedback-batching/EXPERIMENTS.md).
Only measured IV widths and the recorded Zig 0.15.1 / Zen 5 guest support the
timing claims. Default-IV and short-call controls remain in the raw evidence.
CFB IV65 batching was rejected for repeatable short-call cost; it keeps scalar
encryption. No claim establishes physical optimality or universal gains.
Further hypotheses remain open.
