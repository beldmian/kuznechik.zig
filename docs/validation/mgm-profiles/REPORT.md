# MGM profiles implementation evidence — 2026-10-29

Base: main v0.8.0, `5bbffcf`. Worktree:
`/home/t3/.t3/worktrees/kuznechik.zig/t3-7d31553c`.

Final validation (Zig0.15.1):

- Boat J `bx_4bnay2nf`, AMD Ryzen9 9950X, core0, `-mcpu=native`:
  **91/91** tests pass in ReleaseSafe and ReleaseFast.
- Local portable default x86_64 target: **83 passes +2 GFNI skips /85 total**
  in Debug and ReleaseSafe.
- These totals include the entire existing root suite (73 native, or65 portable
  passes +2 skips), plus16 named profile tests and2 test-import blocks.
- The 352-byte Cipher layout is asserted. Existing root/block APIs and raw
  MGM known-answer tests pass unchanged.
- `compiled-source-sha256.txt` was generated on Boat and verified against the
  local files after copying evidence back. All seven entries matched.
- `git diff --check` passes.

The reference generator checks all17 RFC9367 A.1 Kuznyechik records, with exact
published derived keys and original write IVs. It compares every published
ciphertext byte and tag (including prefixes/suffixes of the eight elided long
records). It independently reconstructs their explicitly zero plaintext spans.
All four Kuznyechik RFC9227 Appendix A examples match in full. No KDF oracle
was needed: the RFCs publish all required derived keys. Sixteen additional
synthetic independent reference cases cover multipart authentication boundaries.

Fixture blob SHA256:
`2e17c30f39114c5d15a64fca86f06eb98e661b5e657a9837f4a9f348aa910c5a`.

The Python-only reference dependency is gostcrypto1.2.5; only its raw block
cipher is used. Wheel SHA256:
`5cfc8b4c33d2a110fea0cfcb693b4a5f2b021004b9cf8d6bba8b78aab23d2001`.
There is no runtime dependency on it, Streebog, Python, or a protocol stack.

Compiler archive SHA256:
`c61c5da6edeea14ca51ecd5e4520c6f4189ef5250383db33d01848293bfafe05`.
The installed local and Boat compiler binaries both hash to
`0ee27482eb2e7b19fad58579c107364aa93fbfb54be2d2b9c52cef5f955d6225`.

Reproduction commands are in `commands.txt`. Complete test names and counts are
in `native-{safe,fast}.log` and `local-{debug,safe}.log`, with fresh uniquely
named disk-backed task caches. The source manifest includes all source files
used by the imported root suite, not just the new module. RFC snapshot hashes
are separate in `rfc-sha256.json`.

`benchmark.jsonl` preserves105 unsorted wall-clock samples: seven per15
kind/length configurations. `benchmark-summary.json` is regenerated with
`summarize.py`. The harness is `src/mgm_profiles_bench.zig`. Timings cover
in-place sealing with a borrowed, pre-expanded cipher, one-byte unaligned data,
and lengths64,1024,16385. Key derivation/expansion, network framing and replay
handling are excluded. The raw MGM timing uses5 AAD bytes; other profiles use
their own documented AAD shapes. These are scoped observations, not equivalent
protocol workloads or universal speed/optimality claims. The fixture reference
and correctness tests, rather than these timings, establish correctness.

Integration surface and limits are described in `docs/mgm-profiles.md`.
Profiles accept **caller-derived** record/leaf ciphers. External obligations
include exact HMAC-Streebog TLSTREE/KTREE, key/nonce lifetime, counter advancement,
TLS content/padding validation and negotiated limits, SA anti-replay, packet
framing and network datagram caps. The ESP extent helper excludes outer IP
headers, so the caller checks complete network datagram size separately.

Only new profile/source/test/harness/evidence files and a narrowly scoped raw
MGM multipart-AAD helper are changed. Root exports, README, CHANGELOG, versions,
OpenSpec, and existing block APIs are untouched. No other VMs were used.
Boat J is intentionally left running for root cleanup; its assigned expiry was
10:04UTC. No push, tag, or release was performed.
