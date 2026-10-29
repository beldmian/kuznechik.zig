# Combined RFC mode release validation

The v0.8.0 root suite imports every exported mode through `modes/root.zig`.
Tests cover the existing block implementation, classic modes, GCM, optimized
CCM, MGM, all seven RFC 8645 constructions, generic OCB, and the RFC 9189/9337
cipher compositions. This is finite implementation evidence, not a security or
physical-optimality proof.

Zig 0.15.1 results, with isolated local/global caches:

- Local Broadwell Debug, ReleaseSafe and ReleaseFast: 67 tests, 65 passed,
  two expected GFNI instruction skips, no failures.
- Boat J `bx_4bnay2nf`, Ryzen 9 9950X, native ReleaseSafe and ReleaseFast:
  all 73 tests passed in each mode, no skips.
- Standard `zig build test -Doptimize=ReleaseSafe` and strict OpenSpec validation
  pass. The build and test logs are archived alongside this receipt.

Independent reviews checked the exact implementation hashes before integration:
[MGM/ACPKM](../../reviews/mgm-acpkm-independent-sol-20261029-0835.md) and
[OCB/compositions](../../reviews/ocb-compositions-independent-sol-20261029.md).
Neither review found a blocking defect. Reviewed mode files remain unchanged;
the separate CCM optimization has its own alignment and paired evidence.

Stand-alone worker and review suite totals differ because their entrypoints add
unnamed import anchors and were taken at earlier integration stages. The numbers
above describe the final root suite; inspect the unfiltered logs for actual
test names. `source-sha256.json` records the final source snapshot.

Reproduce with fresh, disk-backed cache directories, substituting an empty
directory for each placeholder:

```sh
zig test src/kuznechik.zig -O ReleaseSafe -mcpu=native --cache-dir CACHE --global-cache-dir GLOBAL
zig test src/kuznechik.zig -O ReleaseFast -mcpu=native --cache-dir CACHE --global-cache-dir GLOBAL
zig build test -Doptimize=ReleaseSafe --cache-dir BUILD_CACHE --global-cache-dir BUILD_GLOBAL
```

Nonce uniqueness, cross-message lifetime accounting, fixed per-key tag policies,
independent key derivation, protocol framing and input stability during two-pass
opening remain caller obligations as documented. Generic AES reference vectors
do not establish a registered Kuznechik protocol profile. External hash-based
KDFs and full TLS/IKE/PBES2 implementations are outside the exported cipher layer.
