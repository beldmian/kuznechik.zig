# Initial native AArch64 CI and AES-192 test-adapter repair

Run [41191228706](https://github.com/beldmian/kuznechik.zig/actions/runs/41191228706)
tested PR head `30a8ad8e0a171b2b36e126b9db2098dc40ab7e5d` through merge commit
`ea184877bb252b7a8a98415e15e1bd9f1b94cccb`, Zig 0.15.2, on native Ubuntu
24.04 ARM runners. The unmodified `validation-3` artifact is preserved in
`initial-baseline/`, including host, source hashes, commands, resource receipts
and complete logs. Baseline LLVM Debug and ReleaseFast each passed 97 tests
with two skips. Baseline LLVM ReleaseSafe failed one of 99 tests (96 passed,
two skipped): the RFC 8645 A.2.2 AES-192 GCM-ACPKM-Master derivation diverged
starting at byte 48, its first rekey boundary. The native-profile job separately
received a runner shutdown signal and exited 143 before artifact upload;
that interruption provides no complete native-profile inventory.

The same ReleaseSafe discrepancy was reproduced on x86-64 under QEMU AArch64
10.0.13 with an `aarch64-linux-musl`, baseline LLVM binary. A small diagnostic
program found the expected ACPKM key in a standalone call, but the last eight
bytes of the key stored during in-context rekeying were `aa` bytes. OpenSSL
3.5.5 independently produced the expected key
`06f25d302b6d8b24b98f7dee55c422fe9ef6f9acd1ff9760` and subsequent counter
block `f5f8b106d27178b1b008c9990b72e287`.

Changing the test adapter constructor input from `@Vector(24, u8)` to `[24]u8`
removes this discrepancy in the observed compiler/target/mode. The key field
remains a vector for the mode factory's key-size metadata. The OCB AES-192
adapter uses the same byte-input convention. This is a workaround for the
observed compilation shape, not a claim that a compiler defect has been
independently reduced or proved. Production Kuznechik and ACPKM algorithms,
RFC expected bytes, and the full test inventory are retained.

The repaired targeted ReleaseSafe run passed seven selected tests on x86-64
and QEMU AArch64 (see `qemu-aes192-releasesafe.log`):

```sh
zig test src/kuznechik.zig -target aarch64-linux-musl -mcpu=baseline \
  -OReleaseSafe -fllvm --test-filter AES192 --test-no-exec \
  -femit-bin=/tmp/kuz-arm-aes192-fixed
qemu-aarch64 /tmp/kuz-arm-aes192-fixed
```

The standalone OCB AES-192 FIPS197 test also passed on x86-64 and QEMU
AArch64 ReleaseSafe (`qemu-ocb-aes192-releasesafe.log`).

QEMU execution is emulated evidence, distinct from native hardware. The complete
native ARM matrix must be rerun after this repair. The matrix runner now prints
failed profile logs directly into the Actions job log as well as preserving
artifacts, so future failures can be diagnosed without downloading the artifact.
