# CCM direct full-block MAC processing

2026-10-29, released v0.5.0 `b2c467c` versus direct full-block CBC-MAC input.
Boat L `bx_evj2atxa`, `/home/user/kuz-ccm-full-block`, AMD Ryzen9 9950X guest,
four vCPUs, KVM, CPU0 affinity. The pre-existing `/home/user/kuz-ccm` evidence
was not modified. `lscpu.json` and `uname.txt` record the guest. Zig0.15.1,
LLVM, `-OReleaseFast -mcpu=native` resolves to `znver5`. The portable comparison
uses the same guest with `-mcpu=x86_64`, without GFNI or the Zen5 backend.

Compiler executable SHA-256:
`0ee27482eb2e7b19fad58579c107364aa93fbfb54be2d2b9c52cef5f955d6225`.
Compiler archive SHA-256:
`c61c5da6edeea14ca51ecd5e4520c6f4189ef5250383db33d01848293bfafe05`.
All measured source file hashes and the harness hash are in `source-hashes.json`.

## Retained change

`Mac.update` completes an existing partial block, consumes full blocks directly,
and buffers only the remainder. Loads go through byte arrays, preserving the
unaligned byte API. Opening feeds each complete privately decrypted block
straight to the MAC state; its final partial block follows the padded buffer
path. AAD has already been padded when payload authentication starts, so the
full-block open path always starts with an empty partial buffer.

Opening remains bounded to a64-block private gamma batch. It compares the tag
before performing the in-place counter pass. No plaintext is released before
successful authentication; a failed tag leaves ciphertext intact. The existing
parameter, length, counter, operation-budget and overlap validations stay before
writes. Cipher layout, feature gates, API signatures and RFC formatting are
unchanged. CCM dimensions remain L2..8, nonce15-L bytes, tag4/6/8/10/12/14/16,
payload `<2^(8L)` bytes and the existing2^61 aggregate block-call budget; these
measurements do not expand any limit.

The preceding tail retuning hypothesis failed repeatability and regression
checks. Its complete rejected evidence is in `../tail-retune/RESULTS.md`.
**No tail threshold change is part of this implementation.**

## Method

`pairs.zig` compares complete released/candidate source modules through CCM seal
and open, with three warm-up pairs and21 measured pairs per case. Width order
is shuffled, pair order randomized, and buffer placement rotated independently.
Two runtime seeds are measured natively and portably; a third native executable
swaps source roles to check binary-layout sensitivity. Reverse raw ratios are
released/candidate and must be inverted for candidate/released comparisons.

Each timing batch operates on distinct messages, with count
`max(4, floor(1048576/(payload_bytes+64)))`. Input/key generation, key expansion,
allocation, input resets, oracle encryption and validation occur outside timing.
Every message has a precomputed12-byte nonce (L3),42 bytes AAD, a16-byte tag, and
an unaligned payload with surrounding guard bytes. The timed loop includes all
CCM work and tag output. Every result byte, guard, and tag is checked against the
released implementation after every warm-up and measured pair. Opening also
checks every plaintext byte. Repeated synthetic nonces across warm-up/sample
resets are benchmark-only; they are not a usage recommendation.

Sizes are0,1,15,16,17,31,32,33,255,1023,1024,1025,65536,1048576 bytes.
Summary values use median paired ratios, p10/p90, and faster-pair counts, with
raw elapsed samples in JSONL. They do not compare separate minima.

## Measurements

Native candidate/released median ratios (less than1 favors the candidate).
The reverse column has been inverted to the same convention:

| Payload bytes | Operation | seed7654321 | seed99887766 | reverse seed44332211 |
|---:|---|---:|---:|---:|
| 1024 | seal | 1.0000 | 0.9968 | 0.9865 |
| 1024 | open | 0.9521 | 0.9544 | 0.9558 |
| 65536 | seal | 0.9990 | 0.9962 | 0.9976 |
| 65536 | open | 0.9515 | 0.9445 | 0.9481 |
| 1048576 | seal | 0.9990 | 0.9968 | 0.9876 |
| 1048576 | open | 0.9478 | 0.9503 | 0.9624 |

Across these three runs, native opening reduces median time by about3.8–5.5%
at the listed sizes. Large-message sealing is roughly tied; no large-message
seal gain is claimed. Small native cases vary; for example, open16 ratios range
from0.9411 to1.0075, so not every size/direction is consistently faster.

Portable ratios for all28 cases per seed range0.9885..1.0032 and
0.9782..1.0064. Large portable processing is roughly tied, with observed worst
median regression0.64%; no material portable regression was established in
these measurements. These are single-guest/compiler results, not a universal
speed guarantee, proof of the original overall speed goal, or physical optimality.

## Correctness and reproducibility

- Released baseline local Debug/Safe/Fast:25 passed,2 GFNI feature skips each.
  Baseline native LLVM Debug/Safe/Fast: all33 passed. These unchanged baseline
  logs are in `../tail-retune/`.
- Candidate local Debug/Safe/Fast:25 passed,2 feature skips each.
- Candidate native LLVM Debug/Safe/Fast: all33 passed in each mode.
- Candidate AArch64 Linux-musl ReleaseFast cross-compilation succeeded; it is
  a compile-only check, not an AArch64 runtime result.
- Standard `zig build test -Doptimize=ReleaseFast` passes on the delivered tree.

`alignment.zig` adds5184 differential cases against released CCM: all byte
offsets0..15, L2/3/8, nine AAD boundaries,12 payload/batch boundaries, and
rotating tags4/8/16. It checks all ciphertext/tag/guard bytes, successful open,
and rejected-tag ciphertext preservation. It is run in native LLVM Debug/Safe/Fast
and portable ReleaseFast; its logs are separate from the33-test main suite.

The suite includes the RFC7801 block/key schedule examples, all24 RFC3610
**AES** CCM packets,49 independent Node/OpenSSL CCM oracle fixtures across all
L values and AAD encoding boundaries, malformed tags/length budgets, the separate all-offset differential check below,
batch/partial tails, overlap rejection before mutation, and unchanged ciphertext
on authentication failure. AES fixtures verify the generic construction; they
are not Kuznechik-specific mode vectors. Native layer tests also exhaust byte
products, substitutions, encoded keys, linear basis vectors and transpose guards.

Reproduce from the repository with an idle compatible CPU0:

```sh
ZIG=/tmp/zig-x86_64-linux-0.15.1/zig \
  sh docs/performance/2026-10-29/ccm-full-block/run.sh /tmp/kuz-ccm-full-block
python3 docs/performance/2026-10-29/tail-retune/summarize.py /tmp/kuz-ccm-full-block
```

`prepare.py` extracts benchmark-only source copies from the fixed base Git
object, applies the recorded candidate, and creates a full candidate tree for
correctness tests; it creates no Git checkout and edits no working source file.
The portable files here use the prefix `portable-`; `run.sh` names the same
configuration `x86_64-`. Correctness logs identify each actual command mode.
