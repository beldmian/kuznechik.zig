# Zen 5 standalone GFNI tail retuning

Measured 2026-10-29 from released v0.5.0 (`b2c467c`), on exclusively assigned
Boat VM L `bx_evj2atxa`, under `/home/user/kuz-tail-retune`. The guest reports
AMD Ryzen 9 9950X, four vCPUs, KVM; timings are pinned to logical CPU0.
`lscpu.json` and `uname.txt` record the actual guest. Zig0.15.1 uses
`-OReleaseFast -mcpu=native` (`znver5`, LLVM). Compiler executable SHA-256 is
`0ee27482eb2e7b19fad58579c107364aa93fbfb54be2d2b9c52cef5f955d6225`;
compiler archive SHA-256 is
`c61c5da6edeea14ca51ecd5e4520c6f4189ef5250383db33d01848293bfafe05`.

## Question and prior evidence

The threshold24 was selected with the older 112-map recurrence64 kernel. The
released Zen5 large-batch path uses encoded Toeplitz64 with75 GFNI maps per
linear layer. The existing
`../continuation-1/toeplitz-tails.json` had already investigated this crossover:
standalone21..23 appeared slightly faster, exact24 was tied, and a lower
prepared-tail cutoff did not replicate. This experiment repeats that unresolved
candidate through the released public APIs; it does not repeat rejected
32-lane recurrence, key representation, or S-box designs. There is no
`src/sliced_small.zig` in this release; the rounded small kernels are in
`src/gfni.zig`.

## Measurement and validation

`pairs.zig` imports two complete source variants and calls public
`Cipher.encryptBlocks` / `decryptBlocks` through noinline wrappers. Inputs and
keys come from runtime seeds. Both directions start with independent arbitrary
input; decryption is checked independently of round trips. Before timing, three
keys (zero, allFF, random), lengths0..127, both directions, and offsets0..3
blocks are compared against the released single-block implementation, including
all guards and the complete352-byte layout constraint.

Widths1..63 and64+width are measured separately. Every timed API call includes
its dispatch, zero padding, copy-in/copy-out, and any encoded key preparation.
The64+tail calls include the full64-block processing and its reuse of prepared
keys. `Cipher.init`, allocation, buffer reset, full output comparison, hashing,
and printing are outside timing. Neither variant gets a cached schedule that
the real API lacks. Input is transformed repeatedly; every final byte and
buffer guard is compared after each warm-up and measurement pair.

Each case has three full warm-up pairs. Width order is shuffled, pair order is
randomized, and buffer placement alternates independently. Raw before/after
nanoseconds, repetition counts, checksums, and per-case ratios are in JSONL.
Summaries use the median of paired ratios, with p10/p90 and faster-pair counts;
they do not compare independently selected minima. The sweep has15 pairs of
20,000 calls; focused confirmations have31 pairs of60,000 calls. The second
full candidate confirmation has15 pairs of40,000 calls.

The `opposite` sweep chooses fresh/prepared padded Toeplitz for widths2..24,
and rounded matrix kernels for25..60, opposite the released policy.
The width64 helper selects Toeplitz, so widths61..63 in that sweep are
unchanged controls; `matrix64-998244353.jsonl` explicitly compares actual
matrix64 for61..63 and125..127. Width1 is
initially an unchanged scalar control. Separate `one-matrix` and `one-toeplitz`
variants compare width1 to padded matrix4 and Toeplitz64, including full64+1.

The rejected production candidate changes only **standalone Zen5 lengths21..23**, in
both directions, to padded Toeplitz64. Exact24 remains a matrix call. Tails
after full64 batches retain the existing threshold24. Non-Zen targets and all
feature gates retain their policy. `reverse-818181.jsonl` swaps source roles in
the executable, so its raw ratio is released/candidate; invert it when comparing
to forward candidate/released ratios. The reverse check probes sensitivity to
binary layout as well as timing order.

## Retained and rejected policies

**No production tail policy change is retained.** Early focused runs and the
reversed-module check favored standalone21..23 by roughly1–7%, and one full
sweep favored them by6–11%. However, `narrow-2236067.jsonl` did not repeat that
win: encrypt21 ratio1.0169, decrypt21 ratio1.0370, and decrypt23 ratio1.0164.
It also showed material regressions in unchanged standalone large-tail paths:
decrypt36 ratio1.0744, decrypt37 ratio1.0720, decrypt50 ratio1.0663,
and decrypt45 ratio1.0618. These paths have the same kernel choice; dispatch,
code layout and VM variability can matter beyond an isolated kernel crossover.
The candidate therefore fails the requested repeated-gain/no-material-regression
gate. Earlier positive runs must not be presented as a production speedup.

Other rejected alternatives:

- Fresh padded64 at2..20: median ratios1.073..2.758 across the two sweeps.
- Rounded matrices25..60: slower than the released Toeplitz choice.
  The explicit matrix64 comparison for61..63 and125..127 had ratios1.754..2.594.
- Lowering the reusable-key threshold to20: tails85..87 were close to tied
  (ratios0.987..1.025), rather than a reliably useful gain.
- Padded matrix4 for one block: standalone ratios1.774 encrypt /1.695 decrypt;
  full64+1 ratios1.118 /1.074.
- Padded Toeplitz64 for one block: standalone ratios4.591 /4.300;
  full64+1 ratios1.667 /1.654.
- Exact24: encryption looked promising in exploratory sweeps, while decryption
  remained tied; the narrower21..23 candidate already failed the retention
  gate. No changed24 policy is proposed.

All variants passed their full-output/guard validation. Baseline and narrow
candidate local Debug/Safe/Fast each passed25 tests with2 feature skips. Native
LLVM Debug/Safe/Fast each passed all33 tests for both variants. The candidate
also passed30 tests compiled for `znver4`, and25 tests with3 feature skips for
`znver5-gfni`. AArch64 Linux-musl ReleaseFast cross-compilation succeeded;
its empty log means a successful compilation, not a runtime test. The native
suite includes the RFC7801 block/key schedule examples, all24 RFC3610 **AES**
CCM packet vectors,49 Node/OpenSSL CCM fixtures, authentication preservation,
byte alignment/overlap cases, and exhaustive GFNI/Toeplitz layer checks. These
AES vectors test generic constructions; they are not Kuznechik mode vectors.

## Reproduction

`prepare.py REPO STAGE` extracts only `src` from the fixed base Git object into
benchmark source copies, then applies the fully recorded variants. It creates
no Git checkout and never modifies the working source tree. `source-hashes.json`
records every file in each measured variant. `run.sh` builds and repeats the
measurements on an otherwise idle compatible machine; set `ZIG` if needed.
Run `python3 summarize.py STAGE` to generate a robust summary from its JSONL.
The archived `summary.json` was generated from the raw files in this directory.

Example (from the repository):

```sh
ZIG=/tmp/zig-x86_64-linux-0.15.1/zig \
  sh docs/performance/2026-10-29/tail-retune/run.sh /tmp/kuz-tail-retune
python3 docs/performance/2026-10-29/tail-retune/summarize.py /tmp/kuz-tail-retune
```

The initial second opposite-policy sweep overlapped briefly with compilation
of the narrow candidate. The first sweep and all narrow/reverse confirmations
ran without a compiler or correctness suite sharing CPU0. Sweep2 is retained
as exploratory evidence; production selection relies on the clean candidate
confirmations. VM frequency and host contention remain sources of variation.
The observed gains apply to this compiler/guest and these workloads; they do
not prove a universal cutoff, the original overall speed goal, or physical
optimality. The failed tail hypothesis led to the separate CCM full-block experiment
in `../ccm-full-block/`. No CCM result is implied by these tail receipts.
