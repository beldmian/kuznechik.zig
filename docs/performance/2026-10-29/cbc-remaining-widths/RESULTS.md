# Remaining CBC widths against exact released v0.9.3

Retain the existing independent-lane CBC batching algorithm for the remaining
**53 IV widths in 4..63**, using the compact predicate `iv_blocks >= 2`.
The previously measured widths and their thresholds are unchanged. This is a
throughput win with small measured short-call tradeoffs, not an assertion that
every API call gets faster.

Baseline: exact v0.9.3 `567ab5e19531c2d746f6bfee489f58177933ea61`.
Guest: **AMD Ryzen 7 9700X**, Zig 0.15.1, ReleaseFast, CPU0. Native and portable
(`-mcpu=baseline`) are compiler targets on this same exclusive Boat guest.
The full candidate uses exactly the released cipher kernels; earlier-release
ratios are never added to these measurements.

For newly enabled widths, whole 16 KiB elapsed candidate/baseline ratios span
**0.094892–0.480887 native** (51.9–90.5% less time) and
**0.409725–0.530806 portable** (46.9–59.0% less time). Split-after-block-one
ratios span **0.097844–0.478918 native** and **0.412225–0.531697 portable**.
Every aggregate cell that actually enters a newly enabled batch improves;
the worst is **0.737960 native / 0.751549 portable**, at IV5 split144 bytes.
These direct public-API results include context init/Cipher and IV copy,
plaintext copy, encryptBlocks preparation, and complete encryption, excluding
key expansion, RNG, allocation, reference/comparison/guard checks and hashing.

## Complete newly enabled width coverage

Each entry is the median of five run medians, each drawn from nine alternating
paired samples after two warmup pairs. Whole and split lengths are 16384 bytes.
See `final-summary.json.gz` for all short/entry/loop/ring/large cells, individual
pair ratios and per-run medians, including reversed module placement and
aligned/unaligned/swapped output buffers.

| IV blocks | Native whole | Native split | Portable whole | Portable split |
| ---: | ---: | ---: | ---: | ---: |
| 5 | 0.480887 | 0.478918 | 0.496712 | 0.500015 |
| 6 | 0.398851 | 0.406531 | 0.440732 | 0.443725 |
| 7 | 0.345217 | 0.345893 | 0.530806 | 0.531697 |
| 9 | 0.338519 | 0.343689 | 0.501651 | 0.501739 |
| 10 | 0.308886 | 0.312425 | 0.463443 | 0.466391 |
| 11 | 0.279348 | 0.280162 | 0.522050 | 0.518060 |
| 12 | 0.243229 | 0.247412 | 0.409725 | 0.412225 |
| 13 | 0.288013 | 0.292986 | 0.459201 | 0.460960 |
| 14 | 0.275229 | 0.274911 | 0.429218 | 0.427949 |
| 15 | 0.254076 | 0.258418 | 0.478132 | 0.474978 |
| 17 | 0.266708 | 0.273088 | 0.457856 | 0.462720 |
| 18 | 0.255288 | 0.256217 | 0.445091 | 0.445248 |
| 19 | 0.240544 | 0.239382 | 0.478806 | 0.476863 |
| 20 | 0.222157 | 0.227453 | 0.416259 | 0.418900 |
| 21 | 0.257299 | 0.258432 | 0.440752 | 0.446247 |
| 22 | 0.241908 | 0.243711 | 0.422962 | 0.426570 |
| 23 | 0.235023 | 0.238833 | 0.454229 | 0.454225 |
| 25 | 0.198218 | 0.201386 | 0.451186 | 0.450308 |
| 26 | 0.185908 | 0.187538 | 0.433145 | 0.434433 |
| 27 | 0.180388 | 0.183126 | 0.462047 | 0.461595 |
| 28 | 0.171981 | 0.175523 | 0.411251 | 0.413229 |
| 29 | 0.175530 | 0.176733 | 0.440376 | 0.441617 |
| 30 | 0.167311 | 0.170889 | 0.423602 | 0.426678 |
| 33 | 0.152078 | 0.153118 | 0.440625 | 0.443512 |
| 34 | 0.148795 | 0.152468 | 0.436886 | 0.439047 |
| 35 | 0.145246 | 0.146169 | 0.448975 | 0.447993 |
| 36 | 0.139493 | 0.142480 | 0.421539 | 0.423031 |
| 37 | 0.139682 | 0.141311 | 0.437742 | 0.436291 |
| 38 | 0.133287 | 0.135560 | 0.424856 | 0.426405 |
| 39 | 0.137250 | 0.138896 | 0.442515 | 0.443848 |
| 40 | 0.130634 | 0.132858 | 0.429112 | 0.428760 |
| 41 | 0.126280 | 0.128249 | 0.441454 | 0.444359 |
| 42 | 0.125286 | 0.126958 | 0.425020 | 0.429555 |
| 43 | 0.121224 | 0.123279 | 0.445581 | 0.444497 |
| 44 | 0.117236 | 0.119641 | 0.418333 | 0.419565 |
| 45 | 0.118281 | 0.120087 | 0.435702 | 0.436318 |
| 46 | 0.116600 | 0.117497 | 0.418971 | 0.420578 |
| 47 | 0.117400 | 0.119059 | 0.439561 | 0.438410 |
| 48 | 0.112128 | 0.112065 | 0.427949 | 0.429984 |
| 49 | 0.113419 | 0.115571 | 0.436843 | 0.438725 |
| 50 | 0.111696 | 0.113522 | 0.424241 | 0.424921 |
| 51 | 0.107171 | 0.110977 | 0.439890 | 0.442980 |
| 52 | 0.105330 | 0.107045 | 0.418796 | 0.420098 |
| 53 | 0.109162 | 0.110389 | 0.433183 | 0.430805 |
| 54 | 0.101381 | 0.103296 | 0.423067 | 0.426283 |
| 55 | 0.105293 | 0.106200 | 0.436756 | 0.437660 |
| 56 | 0.098222 | 0.102768 | 0.426864 | 0.429276 |
| 57 | 0.097597 | 0.099093 | 0.433682 | 0.437030 |
| 58 | 0.098487 | 0.099072 | 0.422965 | 0.424297 |
| 59 | 0.097276 | 0.098274 | 0.438221 | 0.436578 |
| 60 | 0.094892 | 0.099757 | 0.418313 | 0.423351 |
| 61 | 0.097159 | 0.099360 | 0.434653 | 0.431698 |
| 62 | 0.095772 | 0.097844 | 0.419044 | 0.421145 |

## Costs, controls and selection

All 53 widths have substantial gains in every aggregate batched cell; none was
excluded on the basis of a noisy short-call result. The worst scalar-only
aggregate is **1.020034 native** (IV62 split16) and **1.015354 portable**
(IV27 whole48). Tiny differences are not speedup claims.

There are repeatable small costs, which the aggregate control envelope must
not hide. Native IV18 split16 has ratio **1.016567**, with five run medians
1.009804/1.016567/1.014676/1.023719/1.035425; the corresponding unchanged
baseline control is 0.996886. Portable IV27 whole48 has ratio **1.015354**,
with medians 1.007940/1.015550/1.018210/1.015354/1.014911; its unchanged control
is 1.000719. These support roughly 1–2% short-call overhead for some
instantiations, consistent with adding entry dispatch; the mechanism is not
proved by timings alone. This retained tradeoff buys the measured 25–90%
reductions in batched workloads. No zero-regression or per-call optimality
claim is made.

The initial three-seed IV29 whole16 result, 1.032563, does *not* repeat at that
scale: the additional forward/reversed medians are 1.003151/0.984718 and the
five-run median is 1.015650. It remains fully visible in `initial-analysis.txt`
and the raw archive. Likewise, the initial unchanged native IV128 split4080
control reaches 1.047806 across three runs (including one run at 1.163773),
but its five-run median is 1.001362. This is an aggregate control outlier,
not evidence that a 4.8% production regression is acceptable.

Final unchanged baseline-v-baseline aggregate maxima are **1.014677 native /
1.009206 portable**. Existing-width candidate controls, including default IV1,
IV2/3 and IV64/65/128, reach **1.007186 native / 1.010256 portable**. Every
raw cost/outlier remains retained. `analysis.txt`, `control-analysis.txt` and
`*-summary.json.gz` give the complete distributions. Near-entry full/split
measurements are separated according to whether either public call can actually
reach the 64-byte dispatcher.

## Correctness and contracts

Only the CBC eligibility predicate changes in production. The batch count stays
`min(64, IVblocks, remaining_full_blocks)`, so no group crosses a feedback
dependency, and scratch remains bounded by `min(64, IVblocks)`. CBC length
validation still precedes all context/data writes. IV2's 128-byte entry and
IV3's 48-byte entry/loop thresholds, default IV1, all >=64 paths and all CBC
scalar/decryption bodies are unchanged. Every CFB production line is identical
to v0.9.3, as are OFB/CMAC/CTR/ACPKM, exports, assembly kernels, versions,
Cipher's 352-byte layout, fields/key values, and authentication boundaries.
There is no new API, heap allocation or external prepared-key cache.

Two new CBC-only tests instantiate all 53 newly eligible widths for independent
AES and Kuznechik physical byte shift-register references. They cover every byte
alignment, whole blocks and short/entry/loop/ring crossings, empty updates,
partial-group tails, wrapped continuing contexts, inverse output, mixed
encrypt/decrypt continuation and every observable context field. Invalid lengths
1/15/17/47/49/63/65/127/129/1025 reject atomically for both directions after
valid updates, preserving all guarded bytes and context fields. Existing
all-mode/authentication and OCB schedule suites remain enabled.

| Configuration | Actual sequential named inventory |
| --- | --- |
| Exact baseline native ReleaseFast | 103 passed |
| Exact baseline portable ReleaseFast | 95 passed, 2 expected skips |
| Final native LLVM Debug / ReleaseSafe / ReleaseFast | 105 passed each |
| Final native self-hosted Debug | 97 passed, 3 expected skips |
| Final portable Debug / ReleaseSafe / ReleaseFast | 97 passed, 2 expected skips each |
| Final znver5-gfni / znver5-avx512vbmi / znver5-avx2 LLVM ReleaseFast | 97 passed, 3 expected skips each |
| Final linked AArch64 Linux GNU ReleaseSafe | Actual statically linked ARM aarch64 ELF compiled; not executed |
| Exact-v0.9.3 layout/atomic rejection and mixed direction continuation | 8/8 each |
| Local focused portable ReleaseSafe | 7/7 (two new CBC tests plus five import discovery tests) |

The auditor verifies every inventory number in sequence, named CBC/OCB tests,
counts and skips, rather than accepting exit status or a stale cached binary.
All invocations use fresh disk-backed caches. Two local full-suite compile
attempts were SIGKILL/137 before emitting test names; neither is a validation
pass. The expanded layout driver initially needed a higher compile-time branch
quota; its rejected compile receipt is preserved under `attempts/` in the raw
archive. Corrected drivers passed with fresh caches. Production source was
unchanged across those driver-only fixes.

## Evidence, reproduction and limits

There are **21100 final + 21100 unchanged-control raw rows / 379800 measured
pairs**, plus two warmup pairs per row. Each group has 4076 distinct aggregate
cells across both targets. Five runtime seeds vary keys, IVs, plaintext and
address/module placement. All final enabled widths were measured directly;
16 KiB summaries do not replace the short/ring/whole/split coverage.

`candidate-source.tar.gz` is a complete source-only reproduction folder;
`baseline-v0.9.3.tar.gz` is the immutable release archive. `prepare.py`,
`run.sh`, `run-tests.sh`, `after.sh` and [COMMANDS.md](COMMANDS.md) describe exact
commands and timing boundaries. `evidence.tar.gz` compresses every raw timing,
full validation receipt, assembly/object/nm capture, machine/compiler identity
and final VM source manifest. `verify.py` checks baseline identity, allowed
source scope, every source hash, exact grids/seeds/layouts/repetition counts,
all named inventories, all exported wrappers and completed VM deletion.
`SHA256SUMS` inventories artifacts. `EXPERIMENTS.md` preserves the actual
hypothesis, noisy pilot decisions and infrastructure/compiler failures.

The exclusive VM **bx_dzmcsqs6**, created with no environment/snapshots and TTL
10800, was deleted only after all evidence was downloaded and verified locally.
`boat-deleted.json` and `boat-deletion-status.json` confirm completed deletion.
No other worker's VM was accessed. No push, PR, tag or release was made.

This is finite warm-loop evidence for one virtualized Zen 5 CPU/compiler. It
does not establish cold-cache behavior, other-CPU performance, constant-time
behavior, every possible caller's code generation, or physical optimality.
The small scalar-call overhead is a documented limitation of this throughput
change, and the remaining setup/tail hypotheses were not modified or claimed.
