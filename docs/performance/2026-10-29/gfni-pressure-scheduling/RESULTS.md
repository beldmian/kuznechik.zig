# Nonuniform ready-node scheduling of the retained 70-map DAG

**No production change is retained.** Every measurement here compares only with
released **v0.9.3**, `567ab5e19531c2d746f6bfee489f58177933ea61`.
The new schedules do not demonstrate a repeatable public-API improvement in both
directions. The existing core remains unchanged; these are useful rejections,
not an optimality claim. No historical gains are added to these results.

## Public API outcome

Elapsed candidate/v0.9.3 ratios, lower is faster. Each cell is the median across
22 affected widths, each width itself the median of **31 alternating paired
samples**, following three warm-up pairs. Samples target 1,048,576 blocks per
implementation. Two seeds use forward module placement; the third reverses it.
The analysis inverts each raw paired ratio for reversed runs.

| Schedule / run | Encrypt | Decrypt |
| --- | ---: | ---: |
| ready00, 902902 | 1.001036 | 1.005460 |
| ready00, 902903 | 1.000341 | 1.005680 |
| ready00, reversed 902904 | 1.001585 | 1.006129 |
| ready12, 902902 | 1.005984 | 1.013209 |
| ready12, 902903 | 1.005758 | 1.002704 |
| ready12, reversed 902904 | 1.008299 | 1.004902 |
| unchanged copy control, 902902 | 0.998611 | 0.998597 |
| unchanged copy control, 902903 | 0.998826 | 0.999738 |

`ready00` has encryption near parity and a repeatable aggregate decryption cost
of 0.55–0.61%. Its 64-block decrypt ratios are
1.012029 / 1.009403 / 1.006409. `ready12` costs 0.58–0.83% in aggregate encryption
and 0.27–1.32% in decryption. Its apparent exploratory decryption gain does not
repeat. Individual widths can improve or regress; every width, including noisy
costs, is retained in `summary.json` and `raw-timings.tar.gz`.

The nine-pair exploratory aggregate ratios, with 262,144 target blocks/sample:

| Schedule | Encrypt | Decrypt |
| --- | ---: | ---: |
| unchanged copy | 1.002348 | 1.001483 |
| ready00 | 0.998499 | 1.005979 |
| ready12 | 1.003363 | 0.996237 |
| ready18 | 1.004419 | 1.000176 |
| ready19 | 1.008520 | 1.020445 |

The latter two were rejected without longer confirmations. The generic x86_64
portable control run uses 15 pairs, 131,072 target blocks/sample and seed 902905.
Its affected-width medians for unchanged-copy / ready00 / ready12 are
0.999643 / 1.000228 / 0.999891 in encryption and
0.999732 / 0.999641 / 0.999882 in decryption. These are unchanged-path controls,
not portable speedups. Single portable case medians range from 0.964205 to
1.030429 across the controls; no noisy sample is removed. An unchanged direct
encrypt control in the ready12 forward executable reaches 1.020356 in one run.
Small, isolated differences therefore should not be read as resolved gains.
`data-audit.json` audits **16 complete files, 1,056 cases, 22,308 measured pairs**.

## Different search, same algebra

Read the approved performance/mode proposals and the complete operand-scheduling
and bitwise-normalization reports before this work. `prepare.py` pins their
existing derivation to v0.9.3 and asserts byte-identical reproduction of **every
source file**, not just mathematical equivalence of the core.

`search.py` explores 24 bounded parameter sets, yielding **23 distinct schedules**
(one duplicate, ready13). It selects only dependency-ready nodes using remaining
last-use releases, weighted critical path, proximity to the original order,
nonuniform output-ancestor preferences, output-completion weights and seeded
bounded perturbations. All 70 multiplication nodes, 179 XOR nodes, their exact
operands and coefficients, normalized matrix, row/column scales, S-boxes and key
semantics remain unchanged. The existing first-eight one-use tied XOR policy is
fixed for every candidate; ties are not reselected opportunistically.

`audit-novelty.py` canonically maps the prior six uniform recursive and eight DFS
orders onto the same DAG. **All 23 orders are different from all 14 prior orders.**
Thus this does not merely repeat those earlier experiments. The 270-node
unsimplified derivation includes dead/identity nodes; schedules emit the same
249 live arithmetic nodes as the release, including the 16 seeded output XORs.

`pressure-audit.json` includes all 16 initial input vectors, retained completed
outputs, and explicitly describes current/ten-key residency scenarios, the matrix
base GPR, memory-broadcast GFNI constants, compiler-dependent S-box constants,
endpoints, counters and transpose context. The baseline has graph-only peaks of
32 before last-use release / 31 after release. The best new schedules also have
31 after release; others reach 73. These counts are source proxies, **not hardware
register proofs**. The ten round keys need not all be resident, nor may constants
and wrapper context simply be assumed absent. LLVM can erase source ordering or
choose different hoisting, allocation and rematerialization.

## Full generated cipher screening

Zig 0.15.1 LLVM, `-OReleaseFast -mcpu=native`, exclusive Ryzen 9 9950X guest.
`codegen.zig` exports both seeded linear and complete cipher/public 64-block
wrappers. LLVM shares prepared bodies; `codegen.py` includes the transitive local
call closure, counts stack memory references through both rsp and rbp, and counts
loop bodies once, not dynamic nine-round instruction totals. Full wrappers include
key preparation, transpose and endpoints. Actual timed public calls decide the
outcome, including dispatch and widths not represented by a static 64-block wrapper.

| Variant | Linear insns / stack refs | Public encrypt closure | Public decrypt closure |
| --- | ---: | ---: | ---: |
| v0.9.3 | 310 / 36 | 653 / 36 | 1057 / 93 |
| ready00 | 316 / 42 | 648 / 38 | 1053 / 87 |
| ready12 | 318 / 42 | 652 / 40 | 1054 / 89 |
| ready18 | 316 / 40 | 661 / 43 | 1056 / 89 |
| ready19 | 324 / 48 | 666 / 50 | 1082 / 113 |

All 23 generated full wrappers were screened. None reduces stack references in
both full directions. The ready00 instruction reductions did **not** translate
into a public-API win. `codegen.json` contains every count, call closure, opcode
histogram and assembly hash; `all-assembly.tar.xz` contains the complete assembly.
`measured-sources.tar.xz` preserves every exact generated source, input fixture and harness.
`timed-binary-assembly.tar.gz` preserves disassemblies of all ten actual timed
binaries, with their identity receipts and a separate portable instruction audit.

## Measurement boundaries and checks

Own exclusive Boat VM **bx_rkpswsaz**, created by this worker using
`boat new --no-env --no-snapshots --ttl 10800`, with every JSONL event parsed
individually. No pre-existing or other worker VM was used. CPU, kernel and
compiler identities are in `vm-identity.log`; both supplied toolchain hashes
match. VM compiler/test jobs use CPU 2, timings CPU 0. Compilation, correctness
runs and timing phases are serialized on the VM. Unique disk-backed caches live
under `/home/t3/.cache` and `/home/user/.cache`.

`pairs.zig` calls actual `Cipher.encrypt`, `decrypt`, `encryptBlocks` and
`decryptBlocks`. Runtime keys and inputs, dependent direct/singleton chains and
independent wider calls remain observable. Every public batch timing includes
per-call dispatch, encoded key preparation, transpose, endpoints, padding and
copies. There is no external prepared-key cache. `Cipher.init`, input resets,
validation, checksumming and printing are outside timing. Buffers are automatic
stack arrays; no allocation occurs inside timing. Public calls operate in place
on buffers whose outputs feed the next timed call.

Widths are 1/2/4/8/12/16/20/21/23/24/25/31/32/47/63/64/65/79/87/88/89/95/
127/128/129/255/256/257/1024/1025/4096/16384 plus direct single-block APIs.
Widths shuffle per seed. Pair order strictly alternates. Buffer roles rotate and
addresses cycle through all four legal 16-byte offsets modulo 64. Every pair
compares complete output buffers, checks guards and exposes a full-output checksum.
Prevalidation uses zero/all-FF/runtime keys, lengths 0..129 and eleven larger
widths through 16,384, four offsets, independent arbitrary decrypt inputs, and
complete buffer/guard comparisons against individual block operations. Cipher
layout is asserted to be 352 bytes for both modules. No independent minima are
used. Raw per-pair arrays, per-offset medians, quantiles, faster-pair counts,
ns/block, all checksums and seed configurations are preserved.

## Verification and delivery

Offline derivation checks independently reconstruct L from the field recurrence,
validate every 4,096 byte-basis input in each direction (including every binary
basis), recursive equal-block identities and 1,024 seeded dense products. Every
new schedule is independently evaluated against the dense matrix. For all measured
variants, `algebra.zig` additionally executes actual GFNI for every byte basis in
both directions, plus 1,024 lane-distinct dense inputs per direction with 16
seeded keys. Existing native tests independently cover every
byte of position-specific substitutions and both prepared key scales, actual
cipher/reference outputs, direct/tail/batch behavior, unaligned mode byte APIs,
validation preservation and authentication-before-plaintext boundaries.

`audit-tests.py` requires every expected complete log and checks every sequential
number, total, status and name. `test-audit.json` records all **31** test logs:

- Baseline and ready00 native LLVM Debug/ReleaseSafe/ReleaseFast: **103/103**
  each; Debug explicitly uses `-fllvm`.
- ready12, ready18 and ready19 native LLVM ReleaseFast: **103/103** each.
- Baseline and ready00 generic portable LLVM Debug/Safe/Fast: **95 passes,
  two expected skips, 97 entries** each.
- Baseline and ready00 self-hosted native Debug: **95 passes, three backend
  skips, 98 entries** each.
- Baseline and ready00 `znver4`: **100/100** each.
- Each of `znver5-gfni`, `znver5-avx512vbmi`, **`znver5-avx2`**, for baseline and
  ready00: **95 passes, three expected skips, 98 entries**. In particular the
  released v0.9.3 AVX2 feature-gate fallback remains valid.
- Six private actual-GFNI algebra runs: **1/1** each (baseline, identical-copy
  control and four measured alternatives).
- Baseline and ready00 AArch64 Linux-musl ReleaseFast tests compile **and link**
  with `--test-no-exec`. Both outputs are verified statically linked AArch64 ELF
  executables; their hashes and `file` receipts are kept. These are compilation
  results, not AArch64 runtime passes.

All source archives and their individual members were read back and verified
locally, as were every VM artifact hash and the complete transfer's SHA-256.
`binary-audit.json` validates all ten actual timed-binary disassemblies and
confirms zero GFNI/ZMM instructions in all three portable binaries. Generator
regeneration matches all 23 original schedule source hashes; the independent
raw recurrence audit checks all 23 in both directions.

The finite search leaves concrete possibilities: local schedule mutations guided
by actual LLVM full-cipher spill metrics; joint scheduling/tied-operand selection
for nonuniform output order; and direction-balanced latency/rematerialization
models that account for live key/S-box context. These require fresh independent
algebra checks and repeated complete public-API evidence. This work establishes
neither an exhaustive search nor a physical or compiler-independent optimum.

See `REPRODUCE.md` for exact commands. `source-audit.json` pins every production
source to the release and proves that each experimental source differs only
inside the circuit statement schedule. Helper assembly constraints and every
matrix-pool memory clobber remain byte-identical. The working library source,
Cipher fields/APIs, feature/backend/model gates, non-Zen fallback, key lifetime,
mode code and authentication/validation boundaries are unchanged. No GitHub
publication, tag or release is performed by this worker.

After evidence was collected and verified locally, the owned VM was permanently
deleted. `boat-deleted.jsonl` records request operation
`bdop_6cce2f3ba85543f7a47b21067c7338b3`; `boat-deletion-status.json` confirms
**status/stage completed**, completed at **2026-10-29 13:26:44 UTC**, target
**bx_rkpswsaz**. No VM remains assigned to this experiment.
