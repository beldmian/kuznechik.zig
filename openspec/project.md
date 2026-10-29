# Project context

Kuznechik block cipher and allocation-free cipher modes in Zig. The reference
compiler is Zig 0.15.1. Public entry points are `src/kuznechik.zig` and
`src/modes/root.zig`; `build.zig` exposes library, test, benchmark and smoke steps.

## Conventions

Preserve the 352-byte Cipher layout and existing block APIs. Keep acceleration
behind complete target-feature and backend gates. Modes accept unaligned bytes;
validate before writes and authenticate before modifying ciphertext on opens.
Use `zig fmt`, appropriate correctness/reference checks and scoped measurements.
Default cipher/key-expansion paths are not claimed constant-time.

## Evidence and publication

The completed investigation ended on 2026-10-29. The immutable
`research-2026-10-29` tag/release preserves raw research records; current indexes
are in `docs/performance`, `docs/validation` and `docs/reviews`. Future work is
tracked in `docs/OPEN-WORK.md` and repository issues. All Boat VMs were deleted.
Commits and releases are incremental; performance claims identify exact compiler,
CPU, workload, source and baseline. A finite test set does not prove optimality.

## Scope

See `docs/MODES.md` and `docs/RFC-MODES.md` for shipped byte-oriented modes,
compositions and protocol helpers. Hash-based KDFs, complete protocol framing,
replay state and lifetime usage accounting remain external. The fuzzing proposal
is unfinished; fixed-vector smoke checks do not establish mutation coverage.
