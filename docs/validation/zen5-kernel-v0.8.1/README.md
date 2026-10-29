# Zen 5 kernel integration, v0.8.1

The retained graph uses 70 constant GFNI maps and 179 binary XOR nodes per L,
versus 75 and 194 in v0.8.0. The deterministic generator was rerun during root
integration; after Zig formatting, both generated implementation files matched
the integrated files byte for byte. It independently rechecks the RFC recurrence,
4,096 single-byte basis inputs per direction, recursive equal-block invariants,
and 1,024 seeded dense-matrix/key products. See [regeneration.json](regeneration.json).

The combined root suite passes all 73 native tests in ReleaseSafe and
ReleaseFast on Boat L, Ryzen 9 9950X, Zig 0.15.1 with native features. The local
portable ReleaseSafe run passes 65 tests with two expected GFNI skips. The
standard build test also passes. Root runs used fresh disk-backed local/global
caches and their complete logs are saved here.

The implementing worker additionally ran baseline and candidate native
Debug/Safe/Fast, portable Debug/Safe/Fast, feature-disabled and non-Zen target
checks, and AArch64 compilation. Those logs and the paired timing data are in
the [experiment receipt](../../performance/2026-10-29/bitwise-normalization/RESULTS.md).
It records the rejected 69-map variant, generated assembly and exact source
snapshots, scope, and remaining hypotheses.

Only the encoded Zen 5 large-batch graph and its row/column normalization change.
Cipher layout, public block methods, tails, feature/model gates and other CPU
fallbacks remain intact. Matrix-pool assembly reads retain their memory clobber.
The results do not establish physical optimality or universal speed guarantees.
