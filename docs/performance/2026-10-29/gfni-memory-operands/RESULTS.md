# Explicit GFNI affine memory inputs

**Rejected; no production change.** All public API comparisons use exact released
v0.9.4, `cd9c731` (full identity in `source-audit.json`). Initial checkout HEAD
`11816fe` adds research evidence only. Neither explicit-input variant demonstrates
a repeated balanced encrypt/decrypt improvement. The released helper and every
other library source remain byte-identical to v0.9.4. Physical optimality remains
unproven. No push, PR, tag or release was made.

## New representation, fixed circuit

The original linear-factor evidence already rejects scalar `m(holder.value)`:
Zig 0.15.1 stages an address and the affine instruction broadcasts pointer bits.
That is a known invalid form, not a fresh performance result. The small probes
here confirm related failures for `m(*const u64)` and `*m(*const u64)`; a scalar
`*m(u64)` also crashes this compiler (exit 139). None is timed or retained.
`probes/status.log`, source, IR and assembly preserve these diagnostics.

The new valid form passes an **eight-byte by-reference aggregate**:

```zig
return asm ("vgf2p8affineqb $0, %[m]{1to8}, %[a], %[out]"
    : [out] "=v" (-> T),
    : [a] "v" (a),
      [m] "*m" ([1]u64{matrix_pool[coefficient]}),
    : .{ .memory = true });
```

`explicit-clobber` retains the global memory clobber first, separating the
addressing change from the barrier change. `explicit-read` removes only that
clobber, **after** the real read is represented. Actual LLVM IR has constraint
`=v,v,*m` and `ptr ... elementtype([1 x i64])` pointing to the immutable matrix
constant. The read is exactly eight bytes. No variant drops the clobber while
retaining the released hidden pointer read. Other output/input/flags contracts
are preserved. See [Zig 0.15.1 lowering](https://github.com/ziglang/zig/blob/0.15.1/src/codegen/llvm.zig)
and [LLVM indirect constraints](https://llvm.org/docs/LangRef.html#inline-asm-constraint-string);
the emitted IR, rather than surface syntax, establishes this fixture's contract.

The prior 69-map normalization, six uniform orders, eight DFS schedules and
23 ready-node schedules were read before this experiment and are not repeated.
No coefficient, graph node, map count, statement schedule, scale, key seed,
table, S-box, endpoint or calling convention changes. The retained one-use tied
output policy is byte-identical. `novelty.json` records provenance;
`independent-source-audit.json` verifies every source against the release and
limits each fixture difference to the multiply helper body.

## Actual code generation

Zig 0.15.1 LLVM, ReleaseFast native, exclusive Ryzen 9 9950X guest.
Counts include the transitive local-call closure for complete public wrappers;
loop bodies count once, not dynamic nine-round instruction totals.

| Wrapper | v0.9.4 instructions / stack references | Explicit + clobber | Explicit read |
| --- | ---: | ---: | ---: |
| Seeded linear layer | 310 / 36 | 309 / 36 | 309 / 36 |
| Public encrypt | 653 / 36 | 651 / 36 | 651 / 36 |
| Public decrypt | 1057 / 93 | 1056 / 93 | 1056 / 93 |

Both explicit variants remove the pool-base setup from the isolated layer.
All 70 isolated GFNI products use RIP-relative **qword `{1to8}`** broadcasts;
there are no matrix stack slots or widened matrix loads. Removing the clobber
changes some LLVM instruction ordering in the isolated layer, but does not
reduce these instruction or spill counts further. Equal counts do not imply
identical machine code. Full assembly and IR are preserved in `vm-evidence.tar.gz`.

Across the complete codegen object, the released 2,048-byte matrix pool becomes
94 individually addressable eight-byte constants (752 bytes). `.rodata` falls
from 13,824 to 11,776 bytes and `.rodata.cst8` grows from 16 to 768; total readonly
constant storage falls by 1,296 bytes. `.text` **grows 544 bytes**, from 15,097 to
15,641. More RIP-relative relocations appear in the object. Thus fewer setup
instructions do not establish a faster full cipher. `operand-audit.json` checks
actual IR contracts, constants and ELF sections; `codegen.json` preserves full
wrapper counts and call closures. Complete disassembly of all nine actual timed
binaries and their readonly pools are also archived and audited.

## Public API measurements

Candidate/v0.9.4 elapsed-time ratios; lower is faster. Each cell is a median
across 22 affected widths, each itself a median of 31 paired samples. The third
run reverses modules; every raw paired ratio is inverted before aggregation.

| Variant / seed and placement | Encrypt | Decrypt |
| --- | ---: | ---: |
| Unchanged copy / 944001 | 0.999119 | 0.999372 |
| Unchanged copy / 944002 | 1.000254 | 1.001188 |
| Unchanged copy / reversed 944003 | 1.000379 | 1.000208 |
| Explicit + clobber / 944001 | 1.000436 | 1.003777 |
| Explicit + clobber / 944002 | 1.001898 | 1.005531 |
| Explicit + clobber / reversed 944003 | 0.997114 | 0.994254 |
| Explicit read / 944001 | 1.002023 | 0.998264 |
| Explicit read / 944002 | 1.001462 | 1.000720 |
| Explicit read / reversed 944003 | 0.999926 | 0.996495 |

The explicit-read 64-block encryption ratios are 1.006406 / 1.006018 / 0.999808;
its decryption ratios are 1.020704 / 0.998448 / 0.999441. Its 1,024-block encryption
ratios are 1.004555 / 1.007353 / 0.997930; decryption is 0.997652 / 0.996743 /
1.004933. These are mixed results, not a balanced improvement. The clobber form
also has individual native decrypt case medians as high as 1.098275 and 1.090285;
no adverse case or sample is removed.

Small unchanged-path controls across the explicit native runs span 0.969700 to
1.019505. Generic portable affected-width medians for unchanged copy / explicit
clobber / explicit read are respectively 0.999531 / 0.998771 / 0.999952 in
encryption and 1.000498 / 1.000897 / 0.999922 in decryption. Individual portable
case medians range from 0.968928 to 1.039075 across the three executables. These
controls expose noise and layout sensitivity; they are not portable speedups.
Instruction/spill counts and tiny favorable timing differences are insufficient.

`summary.json.gz` preserves **12 complete runs, 792 cases, 21,384 measured pairs**,
including every raw timing array, per-offset median, quantile, faster-pair count,
ns/block and full-output checksum. Original JSONL is in `vm-evidence.tar.gz`.
No independent minima or gains from unrelated experiments are combined.

`pairs.zig` calls actual `Cipher.encrypt`, `decrypt`, `encryptBlocks` and
`decryptBlocks`. Batch timers include dispatch, per-call encoded key preparation,
transpose, endpoints, padding and copies. `Cipher.init`, input reset, comparison,
hashing and printing are outside timing. Runtime keys and inputs feed dependent
direct/singleton chains and independent wider calls. Cipher layout is asserted
352 bytes. Each pair compares whole output/guard buffers; the final whole-output
checksum is recorded. Decryption inputs are arbitrary independent ciphertext,
not just round trips. Three warm-up pairs precede alternating measured pairs;
buffer roles rotate and addresses cycle through all four legal 16-byte offsets.
Each native sample targets 1,048,576 blocks; portable samples target 131,072 with
15 pairs. Widths shuffle per seed: direct single block and batches
1/2/4/8/12/16/20/21/23/24/25/31/32/47/63/64/65/79/87/88/89/95/127/128/129/
255/256/257/1024/1025/4096/16384. Prevalidation compares zero/all-FF/runtime keys,
141 lengths through 16,384 blocks, both independent directions and four offsets
against individual block operations, including every guard byte.

## Correctness and resource ownership

`products.zig` independently constructs all 256 affine matrices with polynomial
long division and verifies every byte and binary basis. Actual optimized GFNI
products exercise every input byte in **each of all 64 lanes**, with distinct
lane inputs, for every nontrivial coefficient (0/1 use the existing shortcuts).
Repeated inlined mixed-coefficient calls use evolving mutable inputs to exercise
constant-pool/CSE/alias behavior. All three variants pass both tests.
`algebra.zig` checks actual forward/inverse GFNI transforms against an independent
raw recurrence for every byte/binary basis, then 1,024 lane-distinct dense states
with seeded keys per direction. Each variant passes. `proof.json` retains the
independently derived matrix, scales, recursive invariants and dense checks.
These are actual vector checks in addition to u8 mathematics.

The named inventory audit verifies **39 complete runtime logs, 3,351 entries:
3,297 passes, 54 expected skips, zero failures**. Names, sequence, totals and
statuses match across fixtures within each profile:

- Baseline, explicit-clobber and explicit-read native LLVM Debug/Safe/Fast:
  **105/105** each. Native Debug explicitly uses `-fllvm`.
- All three portable LLVM Debug/Safe/Fast: **97 passes, two skips, 99 entries**.
- All three self-hosted Debug: **97 passes, three skips, 100 entries**.
- All three `znver4`: **102/102**.
- All three each of `znver5-gfni`, `znver5-avx512vbmi` and `znver5-avx2`:
  **97 passes, three skips, 100 entries**.
- Each source's actual-GFNI product tests: **2/2**; seeded recurrence test: **1/1**.
- All three AArch64 Linux-musl ReleaseFast tests **compile and link**; `file`
  confirms statically linked AArch64 executables. This is not runtime validation.

`test-audit.json.gz` retains every name/status and summary. The suite includes
public independent encrypt/decrypt, batch/tail/alignment, mode vectors, malformed
inputs, validation preservation and authentication-before-plaintext behavior.
Every native explicit timed binary has 255 resolved RIP-relative qword GFNI
broadcast sites spanning 94 matrices; all actual readonly bytes match independently
reconstructed field matrices. All three portable timed binaries have no GFNI/ZMM
instructions. Post-run binary hashes match the pre-timing receipts.

No Cipher fields, key values, APIs, key lifetime, target/backend/model gate,
fixed AVX2 gate, non-Zen fallback, 24-block tail policy, mode, validation or
authentication behavior is changed. There is no external prepared-key cache,
benchmark-only production dispatch or secret-dependent table selection. Constants
remain public compile-time values. No constant-time or security-proof claim.

Owned Boat VM **bx_fkjyea7w** was created with exactly
`boat new --no-env --no-snapshots --type large --ttl 10800 --name kuz-gfni-memory --json`.
Every JSONL event was parsed independently and required to match the created id.
No other worker's VM was accessed. The guest reports Ryzen 9 9950X, eight vCPUs
and 16 GB memory; hardware/OS identity is recorded. Compiler archive/executable
hashes match the supplied c61c5da6… and 0ee27482… values in full in
`vm-compiler.sha256` and `local-compiler.sha256`. Compiler/test jobs use CPU 2;
timings CPU 0. Compiler, correctness and timing phases are serialized. All caches
are unique disk-backed directories under `/home/t3/.cache` or `/home/user/.cache`.
Scripts/harnesses were frozen before launch and checked unchanged afterward.

Every one of the **302 archived VM files** was read back and verified locally,
and all source, named-test, timing, constant-pool and timed-binary audits passed
before deletion. The final archive SHA-256 is
`206a3b4d85f0f53e7dfe0fedc9e0cee6c5dd1023e05ec8323f53204dc3e138c9`.
`transfer-verification.json` and `vm-artifacts.sha256.json` retain the receipts.

The owned VM was permanently deleted. Deletion operation
`bdop_dbe98e79f711484e946e32d87b091a0a` has **status/stage completed** at
**2026-10-29T14:35:30.357Z**, target **bx_fkjyea7w**. Request and completion
receipts are `boat-deleted.jsonl` and `boat-deletion-status.json`. No VM remains
assigned to this experiment. A temporary Boat API refusal during validation was
resolved; the historical same-VM SSH fallback and recovery are documented in
`transport.json` and `boat-access-*.json*`. No credential contents were read.

See `REPRODUCE.md` for exact commands, fixture generation, audits and archive
layout. This finite experiment rejects these two representations on this
compiler/guest/workload; it does not rule out other valid memory-input forms or
establish physical optimality.
