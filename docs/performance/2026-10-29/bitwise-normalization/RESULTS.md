# Recursive bitwise normalization of the Zen 5 linear layer

Retained from v0.8.0, `5bbffcfaa68d5c862eb56cdbb635ca9cae7647d8`, on 2026-10-29.
The 64-block Zen 5 graph now uses **70 constant GFNI maps per L**, previously
75. A 69-map alternative was also constructed and measured, but was not selected.
No tail policy, public API, Cipher field, feature/model gate, or non-Zen kernel
changes accompany this graph.

## New algebraic construction

The previous graph searched a geometric normalization `q^(i-j)` of a Toeplitz
matrix. This experiment instead gives each of the four bits of the byte-position
index its own nonzero field scale:

```
s(i) = product(q[b] for set bits b of i)
Tnew[i,j] = gamma * s(i) * Told[i,j] / s(j)
```

This matrix generally is not Toeplitz. The weaker invariant needed by the
three-product recursion still holds. At a split into halves,
`D(s) = diag(Dlower, q[highest] * Dlower)`. The equal diagonal blocks remain
identical; the off-diagonal blocks acquire reciprocal factors. Each of `A`,
`A+B`, and `A+C` is a linear combination of Toeplitz blocks conjugated by the
same lower-bit diagonal. Induction permits the next split. `prepare.py` checks
the equal-block invariant at **every recursive call**, derives the original
L independently from the RFC recurrence, and verifies the resulting map.

The selected parameters, relative to the released normalized matrix, are
`q = [21,138,187,232]`, `gamma = 152`. An additional reciprocal global split
of the row/column scales maximizes unit endpoint scales. There are 81 scalar
leaves before simplification: eight zero leaves and three unit leaves remove
11 GFNI maps. The source graph has 70 GFNI maps and 179 binary XOR nodes,
versus 75 and 194 previously. The same illustrative depth model remains 11
cycles and creation-order peak remains 32 values. These are graph statistics,
not instruction scheduling or register-allocation proofs.

A deterministic 10,000-restart coordinate search tried 22,158,480 coordinate
values. Its 69-map candidate has five zero leaves, seven unit leaves, and 188
XOR nodes. Minimizing multiplication count alone missed the better measured
tradeoff. `search.c`, search output and compiler identity are archived here.
The search is not exhaustive over all four-scale combinations, and makes no
lower-bound or physical-optimality claim.

Additional exact structure checks reproduce the characteristic polynomial's
16 distinct field roots. All 15 wrap ratios required for a geometrically
normalized circulant are distinct (`proof.json`). Consequently this particular
Toeplitz matrix cannot be made circulant through further row/column scaling:
all entries are nonzero, so diagonal scaling that retains Toeplitz structure
must itself be geometric, and that multiplies all wrap ratios by the same
constant. This negative result concerns that construction only; it does not
exclude other factorizations, bases, or faster algorithms. The previous
polynomial-root and rejected triangular-convolution work was read before this
experiment; neither is claimed as a new result.

## Generated code and decision

`codegen.zig` provides identical exported wrappers for the old graph and both
candidates, compiled by Zig 0.15.1, LLVM, `-OReleaseFast -mcpu=native` on the
assigned AMD Ryzen 9 9950X guest. The isolated seeded linear wrapper changes
from 331 to 318 instructions, with 75 to 70 GFNI maps and 108 to 93 binary
XOR instructions; 51 ternary logic instructions remain. Its stack-memory
instruction count remains 36. The 69-map graph generates 328 instructions and
46 stack-memory instructions, with a 1,536-byte frame versus 1,216 bytes for
the old and selected isolated wrappers.

Full encrypt/decrypt wrappers also include key preparation and endpoints.
They show that the selected graph still increases some stack traffic: static
encrypt stack-memory instructions change from 53 to 57, decrypt from 59 to 67.
The 69-map alternative reaches 71 and 87. Thus the choice is supported by
complete API timings despite remaining register-pressure costs; it is not
inferred from graph counts alone. `codegen.json` contains all counts and the
three complete generated assembly files are archived as `.s.gz`. Counts for
complete wrappers are static code counts, including loop bodies, not dynamic
nine-round instruction totals.

## Public API measurements

Exclusive assigned Boat L `bx_evj2atxa`, `/home/user/kuz-linear-next/stage`,
logical CPU0; compiler jobs pinned to CPU2 and no compiler or correctness job
ran alongside a timed run. Additional feature checks used CPU3 only after the
measurement runs. The guest reports AMD Ryzen 9 9950X, four vCPUs, KVM.
Hardware, OS, compiler and source identities are archived. Compiler executable
SHA-256 is `0ee27482eb2e7b19fad58579c107364aa93fbfb54be2d2b9c52cef5f955d6225`;
archive SHA-256 is
`c61c5da6edeea14ca51ecd5e4520c6f4189ef5250383db33d01848293bfafe05`.

`pairs.zig` calls actual `Cipher.encryptBlocks` and `decryptBlocks` through
noinline wrappers. Every timing includes dispatch, S-box encoding, endpoints,
per-call encoded key preparation, transpose, and padding/copy costs. It does
not retain prepared keys between public calls. `Cipher.init`, allocation,
resetting input, full output/guard comparison, hashing, and printing are
outside timing. Keys and all inputs come from a runtime seed; every output
byte is compared after each pair and all output bytes contribute to its
checksum. Directions use independent arbitrary input, not only round trips.
The single-block cases are dependent cipher chains; other widths contain that
many independent blocks, with repeated API calls transforming their outputs.

Widths are shuffled; pair order is randomized; buffer placement alternates.
Three complete warm-up pairs precede each case. The initial 70-map and 69-map
explorations have 15 pairs and approximately 524,288 blocks/sample. Two full
confirmations have 31 pairs and approximately 2,097,152 blocks/sample, including
single-block chains, independent widths, large batches, and affected tails.
The second confirmation reverses the two modules' placement in the executable.
Raw ratios there are old/new and must be inverted. `summary.json` does this
and reports medians of paired ratios, p10/p90, faster-pair counts, checksums,
and median nanoseconds/block. Ratios are never derived from independently
chosen timing minima.

In `pair70-70002.jsonl`, across the 22 affected widths, the median new/old
ratio is 0.9592 for encryption and 0.9738 for decryption. In reversed placement,
`reverse70-70003.jsonl`, the medians are 0.9689 and 0.9899. **Every affected
width/direction has a paired median below one in both confirmations**; the
smallest benefits are about 0.27%. Unchanged small-call controls range from
0.9952 to 1.0082 in the forward run and 0.9952 to 1.0025 in reverse. There is
no observed material regression in this tested set. The 69-map exploration
has weaker encryption results and more generated stack traffic, so the
70-map graph is selected. These observations are scoped to this compiler,
guest and workloads; host/frequency variation and executable layout remain
sources of uncertainty. They are not universal speed claims.

## Correctness and compatibility

Offline validation covers all 4,096 single-byte basis values per direction,
the exact diagonal matrix identity, every recursive equal-block invariant,
and 1,024 independently randomized seeded dense-matrix products. Existing
native tests additionally exercise every binary basis vector through actual
GFNI instructions, every byte in all position-specific forward/inverse/final
S-boxes, and every byte value in both encoded key schedules. Public API
validation uses zero, all-FF and randomized keys, both independent directions,
lengths 0..127 and four block offsets, and compares complete buffers including
guards against single-block operations. The normal suite expands batch/tail
coverage through 1,025 blocks, transpose/alignment checks and unaligned mode
byte APIs, known-answer vectors, invalid-input output preservation and
authentication-before-plaintext behavior.

Baseline and selected candidate pass **all 73 native tests** in Debug,
ReleaseSafe and ReleaseFast. Local portable Debug/Safe/Fast each report
**65 passes, two GFNI skips, zero failures** (67 total test entries).
The `znver4` runtime feature check passes all 70 entries; `znver5-gfni`
and `znver5-avx512vbmi` each pass 65 with three skips (68 entries).
The AArch64 Linux-musl ReleaseFast cross-compilation succeeds. An empty successful cross-compile log is compilation evidence,
not a runtime test on that architecture. Fresh disk-backed local/global caches
were used under `/home/t3/.cache/kuz-linear-next-85d0007b` and
`/home/user/.cache/kuz-linear-next-85d0007b-{local,global}`. Test names and totals
were inspected explicitly to guard against the previously observed stale
27-test binary.

The benchmark asserts the 352-byte Cipher layout for both variants. The Cipher
definition, block APIs, mode implementation, dispatch, feature/model gates,
released tail thresholds, and 112-map non-Zen recurrence source are unchanged.
The hidden matrix-pool assembly reads retain their explicit memory clobber.
Temporary keys still live only for the actual public call. `integration.json`
and hashes establish that the integrated graph equals the measured 70-map
source; the only subsequent change is the module header explaining that the
scaled matrix now has recursive equal diagonal blocks rather than being
Toeplitz. No authentication or validation boundary has moved.

## Reproduction and next hypotheses

From the repository on an idle compatible host, set `ZIG` if needed and run
`sh docs/performance/2026-10-29/bitwise-normalization/run.sh DISK_BACKED_STAGE`.
`prepare.py` extracts source copies from the fixed Git object; it creates no
Git checkout and changes no working source. The run script uses fresh
per-run compiler caches. Run `summarize.py STAGE` to regenerate timing
summaries. `measured-sources.tar.gz` and `measured-source-hashes.json` preserve
the exact measured sources, including the rejected 69-map alternative;
`source-hashes.json` identifies the final integrated candidate. Reproduce the
search with `cc -O3 search.c -o search` followed by `./search 10000`.

Concrete remaining hypotheses:

- Optimize the bitwise-normalization search for zero-leaf removal and generated
  spills/instructions as well as GFNI count. The 69/70 comparison shows why
  simple map-count ranking is insufficient.
- Reorder the three recursive child computations or output consumption to
  reduce live ranges in the full cipher, particularly decryption. Keep the
  required matrix-pool memory clobber and measure full public calls again.
- Explore a larger diagonal/basis family only with exact equal-block or other
  decomposition checks. The failed circulant test does not establish a
  lower bound on such constructions.

The assigned Boat L remains running for root integration. This work does not
push, tag, release, change exports, or modify root version/OpenSpec files.
