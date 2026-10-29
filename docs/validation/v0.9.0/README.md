# v0.9.0 integration and review resolution

Integration base: v0.8.1 `40f77f43fd964a8ac528bf686ce7c1cda859424d`.
Integrated author commits: OFB `0d73fcc1ac84cf7923cd13e092e4c3fb72e0a07e`,
profiles `b755749cfac5c820bf8d922a9957185865872271`, and GFNI operand selection
`ffd31903599df20e4581ccc7ecdaf5168d554c89`. Root adds the nonce capture,
regressions, OFB scalar dispatcher, public exports and release documentation.

## Independent review resolution

The [original review](../../reviews/mgm-profiles-independent-20261029.md)
found one P2 defect in new `Mgm.sealParts`: optimized aggregate argument
passing could retain a nonce's mutable payload backing storage. Encryption
then changed the nonce before authentication reread it. Root captures the
nonce in owned storage after validation and before encryption. This fix ships
with the new API's first release.

The original native reproducer now returns the expected independent tag
`98cffa8005f2a24b96326d2ce0001ae6`, identical ciphertext, and successful
opening with the saved nonce (`independent/fixed-reproducer.log`). A permanent
regression covers payload lengths 64/512/1024/1025/2049 and offsets 0/1/7/15.
Additional permanent tests exercise payload-backed value nonce arguments in
existing GCM, CCM, MGM and GCM-ACPKM APIs, including failure preservation.
Those existing APIs passed; no defect in them is asserted by this review.

The independent driver is a **program**, executed with `zig run`, not a test
entrypoint. Final native ReleaseSafe and ReleaseFast logs each record 111
independent reference cases, 318 multipart layouts and 7,090 negative checks,
plus independent metadata, alias and exact-limit checks. Both end with
`INDEPENDENT REVIEW DRIVER PASS`. The earlier accidental `zig test` invocation
executed zero tests and is excluded from the evidence.

The `independent` directory preserves the executable driver, reference fixture,
generator, original reproducer, review inventory, proposed fix and final logs.
For reproduction, copy its `review_{driver,vectors,nonce_alias}.zig` and
`review_oracle.bin` into a source-only copy's `src` directory, then run:

```sh
zig run src/review_driver.zig -O ReleaseSafe -mcpu=native
zig run src/review_driver.zig -O ReleaseFast -mcpu=native
zig run src/review_nonce_alias.zig -O ReleaseSafe -mcpu=native
```

The generator uses gostcrypto 1.2.5 only for the block permutation; MGM and
profile formatting are independent. Original generator paths remain historical
and may need relocation in a fresh source copy.

## Final combined verification

- Boat R `bx_758ez2tt`, AMD Ryzen 9 9950X guest, native ReleaseSafe/ReleaseFast:
  **99/99 tests** each (`native-safe.log`, `native-fast.log`).
- Local portable Debug/ReleaseSafe: **91 passes, two expected GFNI skips**,
  93 sequential test entries each (`portable-debug.log`, `portable-safe.log`).
- Standard `zig build test -Doptimize=ReleaseSafe` succeeds. The build log is
  empty on success; `checks.json` records its actual exit code.
- The deterministic operand-scheduling generator regenerates the checked-in
  `toeplitz_core.zig` byte for byte after Zig formatting.

Zig 0.15.1 archive SHA-256:
`c61c5da6edeea14ca51ecd5e4520c6f4189ef5250383db33d01848293bfafe05`.
Executable SHA-256:
`0ee27482eb2e7b19fad58579c107364aa93fbfb54be2d2b9c52cef5f955d6225`.
Fresh disk-backed caches were used for the final functional suites.
`source-sha256.json` binds these checks to library sources;
`evidence-sha256.json` records the evidence files.

## Performance scope

[OFB integration](../../performance/2026-10-29/ofb-core70-integration/README.md)
records the rejected initial short-call regression and retained scalar/batched
dispatcher. [GFNI operand scheduling](../../performance/2026-10-29/operand-scheduling/RESULTS.md)
records independent public-API comparisons, generated assembly and rejected
alternatives. Their baselines differ, so these gains are not combined.
Cipher layout remains 352 bytes. Existing block APIs, feature gates, non-Zen
fallbacks and the 24-block tail policy remain intact.

The 17 published Kuznyechik TLS records and four RFC 9227 examples validate
the cipher profiles with supplied derived keys. HMAC-Streebog KDFs, protocol
framing/state and cumulative key-use enforcement remain caller duties. These
finite implementation and timing checks are neither a formal security proof
nor proof of physical optimality. Further optimization hypotheses remain.
