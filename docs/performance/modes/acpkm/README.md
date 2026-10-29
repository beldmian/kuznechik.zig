# RFC 8645 modes: native integration and paired timings

2026-10-29, Boat `bx_4bnay2nf`, AMD Ryzen 9 9950X guest, pinned to core 0.
Zig 0.15.1, `-O ReleaseFast -mcpu=native`; compile-time Zen 5 block backend.
Section size N=4096 bytes, master lifetime T*=6144 bytes. These are benchmark
parameters, not a recommended lifetime policy for every protocol.

The paired driver uses equal-layout cipher adapters: one loops over raw block
operations, and one forwards batches to `encryptBlocks`/`decryptBlocks`. Mode
formatting, initial expanded keys, input, and section derivations are identical.
Timing includes per-message context setup and all rekeying, but excludes initial
key expansion, allocation, copying and output checking. GCM AAD is the literal
`paired ACPKM benchmark AAD`. Decryption cases compare arbitrary full ciphertext
buffers; authoritative and independent-reference tests establish mode semantics.

Each case uses two alternating warm-up pairs and nine alternating measured pairs.
The seed (123) is supplied at runtime. Every output byte and full tag is checked
against the other adapter after each pair; a full-output checksum is recorded.
All 36 size/operation cases match. Ratios below are medians of paired candidate /
serial elapsed times. These are measurements on one guest, not universal speed
guarantees or evidence of physical optimality.

## One MiB messages

| Operation | Serial median ns | Batch median ns | Paired ratio | Batch MiB/s |
|---|---:|---:|---:|---:|
| CTR-ACPKM | 2894821 | 353955 | 0.120846 | 2825.22 |
| GCM-ACPKM-seal | 2953190 | 444214 | 0.151998 | 2251.17 |
| CTR-ACPKM-Master | 2844537 | 342272 | 0.121266 | 2921.65 |
| GCM-ACPKM-Master-seal | 2861720 | 443793 | 0.153275 | 2253.30 |
| CBC-Master-encrypt | 3154108 | 3151673 | 1.001564 | 317.29 |
| CFB-Master-encrypt | 3174757 | 3156202 | 0.999507 | 316.84 |
| OMAC-Master | 3168645 | 3158477 | 0.991984 | 316.61 |
| CBC-Master-decrypt | 2844677 | 314349 | 0.109634 | 3181.18 |
| CFB-Master-decrypt | 2734771 | 331092 | 0.121357 | 3020.31 |

Serial-feedback encryption and OMAC cannot batch the message dependency. Their
near-one ratios are expected; they are not claimed as batching speedups. CTR,
GCM and CBC/CFB decryption exploit independent work. For all four sizes
(64/1024/16384/1048576 bytes), see [paired.jsonl](paired.jsonl).

## Verification and reproduction

The combined root suite passes **all 55 native tests** in ReleaseSafe and
ReleaseFast. Portable Debug, ReleaseSafe and ReleaseFast pass **47**, with two
GFNI-only skips. Final logs are archived here. An initial native test-cache result
listed an obsolete 27-test suite and was discarded; the final run used isolated
compiler caches and executes every new module. Reproduce from v0.7.0:

```sh
zig test src/kuznechik.zig -mcpu=native -O ReleaseSafe --cache-dir /tmp/kuz-acpkm-check-cache --global-cache-dir /tmp/kuz-acpkm-check-global
cp docs/performance/modes/acpkm/paired-benchmark.zig src/.acpkm_paired.zig
zig build-exe src/.acpkm_paired.zig -mcpu=native -O ReleaseFast -femit-bin=/tmp/acpkm-paired
taskset -c 0 /tmp/acpkm-paired 123 2> /tmp/acpkm-paired.jsonl
rm src/.acpkm_paired.zig
```

`worker-handoff.txt`, `benchmark.zig`, `final.jsonl`, `before-cfb.jsonl` and
`cfb-candidate.jsonl` preserve earlier exploratory measurements and API details.
Those exploratory JSONL files contain medians of five samples, not their full raw
samples, and were not randomized paired runs. Final speed comparisons use the
raw paired records above. The original CFB byte-loop prototype was not retained;
the released full-block CFB path passed independent split/section tests.

All applicable RFC 8645 Appendix A.2 known answers pass, including AES-192 for
the GCM-Master example's stated key. An independent scalar implementation checks
Kuznechik keys/materials, counter and feedback semantics, GHASH, MAC subkeys,
section transitions, partial updates, and full master budgets. Negative tests
check preflight preservation, AEAD tag failures and overlap/adjacency contracts.

Source hashes of the measured production modules are listed in
[measured-source-sha256.txt](measured-source-sha256.txt); original worker hashes
are in `source-sha256.txt`. CPU data is in [lscpu.json](lscpu.json). Compiler
archive SHA-256:
`c61c5da6edeea14ca51ecd5e4520c6f4189ef5250383db33d01848293bfafe05`.
