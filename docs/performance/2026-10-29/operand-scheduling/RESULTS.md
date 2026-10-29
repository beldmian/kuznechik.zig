# Tied operands and scheduling of the retained 70-map graph

This experiment compares directly with **released v0.8.1,
`40f77f43fd964a8ac528bf686ce7c1cda859424d`**. The historical 75-map kernel is
used only to inspect the operand-choice hypothesis, never as the performance
baseline. The historical reproduction directory is unchanged; this directory's
`prepare.py` explicitly extracts the released 70-map baseline.

## Operand choice

The inline `xor3` ties its first vector operand to its result register. In the
historical 75-map source, output zero uses `xor3(T, w181, w98, key0)`: `w181`
has one graph use, `w98` has two. The released 70-map source instead uses
`xor3(T, w99, w173, key0)`: `w99` has two uses, `w173` one. The other first-half
outputs have the same pattern. `operand-analysis.json` records actual graph
uses, independently of the canonical ordering in the algebraic proof.

The selected source swaps only the first eight seeded XORs, so their one-use
limbs become the overwritten operands. The second eight retain their order:
by then both limbs have one remaining use. The generator tracks remaining
output uses, prefers the smaller count, and preserves DAG order on ties.
`proof.json` records all 16 emitted operand pairs. No graph node, constant,
scale, S-box, key encoding, endpoint, assembly constraint, or memory clobber
changes. The source header now points to this generator. Regeneration matches
the integrated source exactly.

## Generated code and alternatives

Zig 0.15.1 LLVM, `-OReleaseFast -mcpu=native`, assigned Ryzen 9 9950X guest.
All wrappers are the existing `../bitwise-normalization/codegen.zig`, including
key preparation and endpoints in full cipher wrappers. Counts are static
instruction counts, including loop bodies, rather than dynamic round totals.

| Wrapper | Released instructions | Selected instructions | Released stack-memory instructions | Selected stack-memory instructions |
| --- | ---: | ---: | ---: | ---: |
| Seeded linear layer | 318 | 310 | 36 | 36 |
| Encrypt | 676 | 660 | 57 | 51 |
| Decrypt | 1031 | 1014 | 67 | 63 |

The isolated layer removes exactly eight `vmovdqa64` register moves. It retains
70 GFNI, 93 binary XOR, and 51 ternary-logic instructions. Its stack frame
remains 1,216 bytes; the encrypt wrapper frame decreases from 1,472 to 1,280
bytes and decrypt remains 1,408 bytes. These results support a concrete
register-allocation explanation without claiming an optimal schedule.

Swapping **all** 16 outputs by total use count (`candidate` in the original
measurement archive, `single` in `variants.py`) gives 311 isolated instructions
and increases full encrypt/decrypt stack traffic to 59/69. Its exploratory
API results are mixed for larger decryption calls, so the stable-tie policy
is preferred.

All six uniform recursive child orders were generated. The usual `p,q,r`
order with the selected operand policy equals the selected wrapper counts.
The other orders generate 65–143 encrypt and 81–201 decrypt stack-memory
instructions, versus 51/63 selected. API explorations for all five alternatives
are retained as `recursive-*-85201.jsonl`. `q,p,r` has some gains but mixed
results, including regressions; the other orders mostly regress encryption.
Eight DFS schedules vary forward/reverse/paired output consumption and dependency
child order. They produce 70–103 isolated stack-memory instructions and 130–197
full decrypt stack-memory instructions. Those schedules were rejected on code
generation evidence without timed API runs. None is described as an exhaustive
scheduling search.

After the selected tied-operand correction was measured, the old 69-map
normalization was regenerated with that correction. It still generates a
1,536-byte isolated frame, 320 isolated instructions, and full encrypt/decrypt
stack-memory counts of 69/78. `proof69.json`, its assembly and API samples
preserve the reevaluation; map count alone is not the selection criterion.

`codegen.json` and `all-codegen.s.tar.gz` contain every generated wrapper and
full assembly. In those original filenames, `candidate` means the exploratory
all-16 swap, `first8` and `recursive-pqr` mean the selected scheduling policy,
`selected` is the earlier generator output, and `final` is the exact integrated
source including its updated generator-reference comment.

## Public API method

Exclusive Boat L `bx_evj2atxa`, `/home/user/kuz-gfni-spills`, logical CPU 0.
Compiler and correctness jobs used CPU 2 and finished before timed runs. No
compiler or correctness suite ran alongside the Boat timings. The prior
`/home/user/kuz-linear-next` and integration evidence were preserved. Compiler
and host identities are in `final-binary.sha256`, `lscpu.json`, and `uname.txt`.
Both local and Boat compiler executables have SHA-256
`0ee27482eb2e7b19fad58579c107364aa93fbfb54be2d2b9c52cef5f955d6225`.

The unchanged `pairs.zig` harness calls the actual `Cipher.encryptBlocks` and
`decryptBlocks` APIs through noinline wrappers. All dispatch, per-call encoded
key preparation, endpoints, transposition, staging, tail padding and copies are
inside timing. `Cipher.init`, input resets, validation and hashing are outside.
There is no prepared-key cache outside the public call. Keys and inputs depend
on a runtime seed. Independent arbitrary decryption inputs are checked, rather
than just encrypt/decrypt round trips. Every output byte is compared after each
pair; guard checks and whole-output checksums remain observable.

Prevalidation compares both complete variants against independent single-block
outputs for three runtime/zero/all-FF keys, lengths 0–127, both directions and
four block offsets, including guards. The layout assertion is 352 bytes.
Timing uses randomized widths and pair order, rotating buffers, and three warm-up
pairs. Single-block calls form dependent chains; wider calls process independent
blocks. Widths cover small controls, 25–63-block tails, 64/256/1024 blocks, boundaries
around them, and 4,096/16,384-block calls. The confirmation runs have 31 pairs
and about 2,097,152 blocks per sample. Two runtime seeds use normal module
placement; a third reverses module placement. Raw ratios in the reversed run
are inverted by `summarize.py`. No independent minima are compared.

## Public API results

| Run | Encrypt median new/released ratio | Decrypt median new/released ratio |
| --- | ---: | ---: |
| final-85301.jsonl | 0.984565 | 0.985557 |
| final-85302.jsonl | 0.986590 | 0.981166 |
| reverse-final-85303.jsonl | 0.984792 | 0.982443 |

These are medians across the 22 affected widths, each itself a median of 31
paired ratios. Every affected width/direction has a median below one in all
three confirmations (132 case medians). Across affected widths, encryption
time reductions have medians of 1.34–1.54%, and decryption 1.44–1.88%.
The weakest individual case is a 0.056% reduction, within measurement noise;
the result does not establish a statistically resolved benefit for every width.
Small-call controls have median ratios from 0.9893 to 1.0060 across these runs.
There is no observed material regression in the selected tested set.

For 64-block calls, the three encrypt ratios are 0.98915/0.98583/0.97456
and decrypt 0.97515/0.98033/0.98202. For 256 blocks, they are
0.97984/0.97628/0.98564 and 0.98189/0.98028/0.97881. For 1,024 blocks,
they are 0.97290/0.98294/0.98282 and 0.98132/0.97970/0.97847.
`summary.json` preserves every case, pair count, faster-pair count,
p10/p90 paired ratios, median ns/block and checksum; the JSONL files
preserve every underlying timing.

The corrected 69-map exploration has affected-width median ratios 0.99363
for encryption and 0.98230 for decryption, but individual affected medians
reach 1.01543 and 1.04160 respectively. It is rejected for mixed API results
and greater stack traffic, despite some decryption gains.

## Correctness and compatibility

`prepare.py` independently derives L from its recurrence, verifies every recursive
equal-block invariant, all 4,096 single-byte values in each direction, and 1,024
random seeded dense-matrix products. `variants.py` checks every binary basis
vector for all six rebuilt recursive orders. Native tests exercise actual GFNI
basis transformations, all byte values in every position-specific S-box and
key scale, full independent outputs, batch alignment/tails, all mode integrations,
unaligned byte inputs, rejection buffer preservation, and private authentication
before plaintext writes.

Released baseline and selected source each pass **all 73 native tests** in Debug,
ReleaseSafe and ReleaseFast. Selected local portable Debug/Safe/Fast and baseline
portable Fast each pass **65 tests with two expected skips** (67 entries).
`znver4` passes 70/70; `znver5-gfni` and `znver5-avx512vbmi` each pass 65 with
three skips (68 entries). AArch64 Linux-musl ReleaseFast cross-compilation
succeeds; the empty log is compilation evidence, not a runtime test.
`audit-tests.py` checks every sequential test number, total, status and name;
`test-audit.json` preserves them, guarding against obsolete cached test binaries.
Fresh unique disk-backed local/global caches were created under `/home/t3/.cache`
and `/home/user/.cache`; cache receipts are included.

Only `src/toeplitz_core.zig` changes in library source. Cipher layout, public APIs,
threshold 24, all dispatch/feature/model gates, non-Zen recurrence fallback,
key lifetime, memory clobbers and authentication/validation boundaries are
preserved. No root README, changelog, version, OpenSpec or exports are modified.

## Reproduction and limits

On an otherwise idle compatible host, run:

```
ZIG=/tmp/zig-x86_64-linux-0.15.1/zig \
  sh docs/performance/2026-10-29/operand-scheduling/run.sh DISK_BACKED_FRESH_STAGE
```

The scripts create source-only copies, never Git checkouts. `prepare.py` pins
v0.8.1 explicitly. `run.sh` rebuilds the alternatives, measures the actual APIs,
and validates native/feature paths. Module labels in a fresh reproduction differ
from the original exploratory `candidate` label as described above. Exact
original measured sources, including the harness, are in
`measured-sources.tar.gz`; `measured-source-hashes.json` and `source-hashes.json`
identify them. `integration.json` checks the delivered source against measured
`final` and the extracted baseline against the released Git object. Full raw
samples and the ratio summaries are included. Portable checks can be reproduced
with `zig test src/kuznechik.zig -O{Debug,ReleaseSafe,ReleaseFast} -fllvm` on a
host without GFNI, using fresh disk-backed caches.

The observations apply to this compiler, guest, executable layouts and tested
widths. Host frequency, scheduling and layout variation remain limitations.
There is no universal speed, security, exhaustive-search or physical-optimality
claim. Boat L is left running for root integration.
