# RFC 7253 OCB evidence

The implementation batches independent payload and AAD work through the released
block APIs. Opening authenticates private plaintext before a second decryption
pass writes the caller's buffer. Nonce/tag formatting, partial blocks, aliases
and per-call limits follow the contracts in [mode documentation](../../../MODES.md).

The implementing worker measured on Boat `bx_74k2jvwb`, Ryzen 9 9950X guest,
core 0, Zig 0.15.1, `-O ReleaseFast -mcpu=native`. The key is pre-expanded,
AAD is 256 bytes and nonces advance during sealing. Each case has seven
alternating serial/batch pairs after warm-up. The serial adapter uses individual
block calls with the same OCB implementation. Opening includes a ciphertext
restoration copy in both paths. Initial key setup and allocation are excluded.

[ocb-bench.log](ocb-bench.log) contains all 42 observations and
[benchmark-summary.json](benchmark-summary.json) their summary. The 1 MiB
batch results are 4512.24 MiB/s sealing and 2153.23 MiB/s opening with the copy
included. These are configuration-specific observations, not universal rates or
physical optimality. The benchmark uses successive changing inputs/nonces and a
digest sink; correctness is established separately by the complete-output tests,
rather than an output comparison after each timed pair.

Reproduce from v0.8.0:

```sh
cp docs/performance/modes/ocb/ocb-bench.zig src/.ocb_bench.zig
zig build-exe src/.ocb_bench.zig -O ReleaseFast -mcpu=native -femit-bin=/tmp/ocb-bench
taskset -c 0 /tmp/ocb-bench
rm src/.ocb_bench.zig
```

The [implementation handoff](HANDOFF.txt) records parameters, exact signatures,
known-answer provenance and original test commands. Its counts describe the
worker's source snapshot; later independent review and combined integration
counts are recorded separately. Original hardware/backend outputs and source
hashes are also archived here. The production OCB SHA-256 is
`2a14340906ec2009f95406fb5c6b14595a6190e7f4cda447c7035bbed051528e`.

All 17 RFC 7253 AES tuples, all nine aggregate checksums, 394 independent
Node/OpenSSL outputs, and 2,208 guarded Kuznechik cases pass. Empty nonces have
separate generic-construction checks because OpenSSL's named AES profile rejects
them. `node scripts/ocb-oracle.cjs` regenerates the public oracle data.

The [independent review](../../../reviews/ocb-compositions-independent-sol-20261029.md)
adds 144 fresh AES-256/OpenSSL outputs covering all tag sizes, read-only sharing
and 282 writable-alias rejection cases. It also validates the RFC compositions.
The final combined [v0.8.0 validation](../../../validation/rfc-modes-v0.8.0/README.md)
includes the optimized CCM path and all mode exports.
