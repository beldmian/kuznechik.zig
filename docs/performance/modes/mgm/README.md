# RFC 9058 MGM evidence

The released implementation uses independent block batches, combines short-message
counters, and accumulates carryless products before a single reduction. PCLMUL
is selected at compile time on supporting x86-64 targets; portable multiplication
remains available. `Cipher` layout and block operations are unchanged.

Measurements were collected on Boat `bx_sxaayb5h`, a Ryzen 9 9950X guest, pinned
to core 0, Zig 0.15.1, `-O ReleaseFast -mcpu=native`. Each message uses 32 bytes
of AAD and a pre-expanded key. Buffers are warm. The benchmark applies sealing
repeatedly in place, so successive input bytes change. Opening additionally
includes restoration of the original ciphertext. Key expansion and allocation
are excluded. Fixed benchmark keys/nonces are measurement inputs, not an example
of nonce management for applications.

[results.json](results.json) records seven sorted timing samples, warm-up and
iteration counts, measured source hash, and verification details. The corresponding
original text outputs are the `*overlap.txt` files in this directory. At 1 MiB,
the final native sealing result is 1550.511 MiB/s. These are standalone throughput
runs rather than paired randomized comparisons; no universal speedup or physical
optimality follows from them. `hardware.txt` preserves an earlier prototype run,
not the final measurement or hardware inventory.

Reproduce the final sealing benchmark from v0.6.0:

```sh
cp docs/performance/modes/mgm/mgm_final_bench.zig src/.mgm_final_bench.zig
zig build-exe src/.mgm_final_bench.zig -O ReleaseFast -mcpu=native -femit-bin=/tmp/mgm-bench
taskset -c 0 /tmp/mgm-bench
rm src/.mgm_final_bench.zig
```

The open and forced-serial drivers are also archived. For the portable-product
driver, first copy `src/modes/mgm.zig` to `src/modes/mgm_final_portable.zig` and
apply [portable.patch](portable.patch) to that copy. It changes only the PCLMUL
selection constant. Copy the selected driver into `src/`, build and run as above,
then remove temporary files. The actual native source hash is
`4e7fe9f2115d8a6517c984e281d8e6209205a9fefedff357cec0c923780f2ee1`.

Correctness evidence includes both official Kuznechik examples from
[RFC 9058 Appendix A.1](https://www.rfc-editor.org/rfc/rfc9058.html#appendix-A.1),
an independent polynomial long-division reference, all short remainders and
64-block boundaries, counter wrap, invalid dimensions, every supported tag size,
tampering and overlap rejection before writes, and ciphertext preservation.
The worker's isolated 12-test suite passed Debug, native ReleaseSafe, baseline
x86-64, x86-64 with PCLMUL but no AVX, and native Boat ReleaseSafe. AArch64 passed
compilation only. Integration logs are saved separately alongside these files.

The independent Go reference is
[BI.ZONE ruwireguard-go](https://github.com/bi-zone/ruwireguard-go/tree/0de9ac51051ee7f20430de8dcb5b132b9d062d18/crypto)
at commit `0de9ac51051ee7f20430de8dcb5b132b9d062d18`. Generators for 844 AES and
844 Kuznechik cases are archived as `generate-aes.go.txt` and `generate-kuz.go.txt`.
Their `independent/mgm` and `independent/gost3412128` imports refer to the upstream
`crypto/mgm` and `crypto/gost/gost3412128` packages copied into a temporary module
named `independent`. The upstream implementation is not distributed with this
library. SHA-256 covers complete ciphertext-plus-tag bytes in generator order;
both expected digests are embedded in the Zig test and in `results.json`.

Compiler archive SHA-256:
`c61c5da6edeea14ca51ecd5e4520c6f4189ef5250383db33d01848293bfafe05`.
