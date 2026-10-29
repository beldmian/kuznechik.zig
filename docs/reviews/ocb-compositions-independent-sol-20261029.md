Independent OCB and composition review, 2026-10-29

No defects found and no integration-blocking objections in the reviewed snapshot.
There is consequently no defect severity, failing reproducer, or fix recommendation.
This is an independent implementation review with executable checks, not a formal
security proof, a physical-optimality proof, or a performance endorsement.

Reviewed main base: 81032ffd800394d9fec124b64010ab9796c65616. OCB and composition
files were untracked and intentionally not exported. Lack of exports was excluded
from findings. AGENTS.md, openspec/AGENTS.md, openspec/project.md, and the proposal,
design, tasks, and cipher-modes delta for add-rfc-cipher-modes were read.

Primary requirements were read from the cached complete RFC texts under
/home/t3/.cache/kuz-rfcs: RFC7253 sections3–5.1 and AppendixA; RFC9189
sections4.1.1,4.3.2–4.3.5,8.2.1 and the relevant AppendixA examples;
RFC9337 sections5.1.1–5.1.2 and7.3; RFC8645 counter mechanics were checked
against the released supporting implementation and its tests.
References: https://www.rfc-editor.org/rfc/rfc7253.html,
https://www.rfc-editor.org/rfc/rfc9189.html,
https://www.rfc-editor.org/rfc/rfc9337.html.

The reviewed implementation SHA256 values are:

```
2a14340906ec2009f95406fb5c6b14595a6190e7f4cda447c7035bbed051528e  src/modes/ocb.zig
ac337479c09d63988d9daeb0088b03b450c197585caa20339857623535113bcb  src/modes/compositions.zig
8c334a877cc3b637002cdcf33affcca27e06e1dfaea3468304733077b3d763dc  src/modes/ocb_test.zig
d0af3118646b4866d10830136949d87d0998925461ad0294b758bbd0b7f3112f  src/modes/composition_test.zig
54d377fe289436e18d7b6787be153801c12d50c1eda79ed7cc2e6a77882f76be  src/ocb_test.zig
9aaa53c01cff9fc794d5bf18d8a8874edd6fd9c040c46a4ae9c4152323956160  src/composition_tests.zig
```

Source inspection confirmed the following behavior:

- OCB lines76–95 implement the tag-dependent nonce encoding, Ktop, stretch,
  and six-bit offset selection. Lines49–69 provide L_0 through L_48 and an
  inclusive per-call bound of ceil(AAD/16)+ceil(payload/16)<=2^48. Lines97–170
  implement the full/partial AAD and payload rules and left tag truncation.
- OCB lines71–74 reject writable aliases with nonce, AAD, tag and cipher
  storage; read-only sharing is permitted. These checks precede writes.
  Lines188–196 authenticate private plaintext before a separate writing pass.
- Composition lines52–63 use IV||secret for KExp15's MAC and ordinary CTR.
  TLS lines75–81,108–130 serialize the sequence/type/version/plaintext length,
  add the sequence to the base IV modulo2^64, and use 4096-byte ACPKM sections.
  Password lines135–166 use no MAC prefix, use UKM's first eight bytes as
  nonce, and require a positive section length divisible by16.
- Composition lines179–205 check expansion and the combined payload+tag
  stream budget. Lines209–230 compute and encrypt the complete tag at its
  actual stream position. Lines232–269 authenticate private 1024-byte batches
  and the continuing encrypted tag before any plaintext output is written.
  Out-of-place output/input aliases and writable context aliases reject;
  explicit in-place open leaves the encrypted tag suffix intact.
- docs/composition-notes.md accurately distinguishes the caller's independent
  ENC/MAC keys and TLSTREE/PBKDF2/KDF_TREE dependencies from the implemented
  cipher layer. It records TLSCompressed's 17408-byte bound, fixed 16-byte
  composition tags, unique nonce duties, and external aggregate key lifetimes.

Every compilation below used Zig 0.15.1 and distinct fresh local/global cache
paths. The source snapshot was transferred to the exclusively assigned Boat J
bx_4bnay2nf under /home/user/kuz-review-sol-20261029. All39 files in its archive
manifest passed SHA256 verification; the named module tests below were present
in every corresponding unfiltered log. This avoids relying on the previously
reported stale27-test cache result.

Commands and results:

- Local Intel Xeon E5-2690 v4/Broadwell, default target:
  `zig test src/ocb_test.zig -O ReleaseSafe --cache-dir <fresh> --global-cache-dir <fresh>`:
  60 total, 58 passed, 2 existing GFNI instruction tests skipped, 0 failed.
- Same local settings, `src/composition_tests.zig`:
  58 total, 56 passed, 2 existing GFNI instruction tests skipped, 0 failed.
- Boat AMD Ryzen9 9950X/Zen5, pinned core0, `-mcpu=native`:
  `src/ocb_test.zig` passed all 66 tests separately in ReleaseSafe and ReleaseFast.
- Same Boat settings, `src/composition_tests.zig` passed all 64 tests separately
  in ReleaseSafe and ReleaseFast. Neither Boat suite had a skip.
- Three additional independent named review tests, filtered by `review_sol`,
  passed locally in ReleaseSafe and ReleaseFast, and on Boat in native
  ReleaseSafe. Each filtered log has 7 passing entries: 3 named review tests
  plus 4 unnamed import-discovery tests. These are not seven new named tests.
- `zig fmt --check` passed for both implementations, both primary test files,
  the AES192 OCB adapter, and both standalone suite entrypoints.
- `node scripts/ocb-oracle.cjs` regenerated the 394-case JSON byte for byte.
- A copy of composition_reference.py run outside the repository regenerated
  all 162 complete outputs and the formatted Zig index byte for byte. Binary
  size 440262; SHA256 d4aede6123195bb246e09efb600e8625915a4aa67467dd96ff6bef50b6468526.

The eight OCB named tests and the helper test actually run were:

```
modes.ocb_test.test.RFC7253 Appendix A all sixteen AES128 tuples and tag96 tuple
modes.ocb_test.test.RFC7253 Appendix A all nine aggregate checksums
modes.ocb_test.test.394 independent Node OpenSSL OCB fixtures all byte nonce and tag lengths all bottom bits
modes.ocb_test.test.Kuznechik OCB all small tails 64-block boundaries every alignment guards and rejection
modes.ocb_test.test.OCB fixed dimensions budget and alias failures preserve output
modes.ocb_test.test.OCB key storage aliases and read-only sharing
modes.ocb_test.test.OCB independent work batches stop at64 and open authenticates in a separate pass
modes.ocb_test.test.generic RFC7253 empty nonce is distinct from named AES profile limits
modes.ocb_aes192_test.test.test-only AES192 matches FIPS197 C.2
```

The seven composition named tests actually run were:

```
modes.composition_test.test.RFC9189 A.1.3.2 Kuznyechik PMS export and import exact known answer
modes.composition_test.test.RFC9189 A.1.2.2 Kuznyechik TLS records 0 63 64 including meshing
modes.composition_test.test.independent Python Kuznyechik oracle full outputs all alignments and 64-block section boundaries
modes.composition_test.test.every ciphertext or tag byte corruption and wrong keys nonce metadata preserve all buffers
modes.composition_test.test.composition preflight lengths sections overlap adjacency and TLS IV modulo
modes.composition_test.test.expanded mode budget and immutable cipher configuration are checked before writes
modes.composition_test.test.composition altered nonce keys section truncation extension preserve caller outputs
```

New review checks went beyond the shipped fixtures:

- 161 complete Kuznyechik composition outputs generated by a new Python
  implementation using gostcrypto1.2.5 only for raw block encryption. The seed
  was 0x725391899337. Each case uses fresh independent random ENC/MAC keys,
  IV and payload; TLS also varies 64-bit sequence, content type and version.
  The23 lengths were0,2,14,18,47,48,49,79,80,81,1006,1010,1038,1040,1041,1042,
  2047,2048,2049,4110,4112,4113,5009. Families were KExp15, TLS, and password
  sections 48,80,1008,1040,4112. These sections exercise rekeys that do not
  divide the private 1024-byte scratch size. Full seal outputs, valid open,
  unchanged encrypted tag suffixes and exterior guards all matched.
- 144 new complete AES256 OCB outputs from Node20.19.2/OpenSSL, each with a
  different deterministic SHA256-generated key/nonce/AAD/payload, all 16 tag
  lengths, nonce lengths 1–15, payload lengths 2,14,18,47,79,1010,1042,2049,5009,
  and AAD lengths 2,14,18,63,79,1040,1042,2048,5007. Full ciphertexts and tags,
  rejection preservation, and valid opens matched.
- A successful OCB seal/open using a nonce and AAD that share each other and
  read-only AES key storage matched copies of those inputs. An exhaustive
  start-offset scan for a 33-byte payload checked 282 writable nonce/AAD/tag
  alias rejections, preserving the entire 96-byte arena and detached tag.

The new named tests were:

```
.review_sol_20261029.test.review_sol new independent Kuznyechik compositions irregular sections random keys and metadata
.review_sol_20261029.test.review_sol additional AES256 OpenSSL OCB independent tuples every tag size
.review_sol_20261029.test.review_sol OCB readonly nonce sharing and exhaustive small writable aliases
```

Evidence, new generators, full fixtures, the temporary driver's saved copy,
all unfiltered logs, Boat CPU identification and the 39-file source manifest
are retained at /tmp/kuz-review-sol-awD48G. The new driver copy is
review-driver.zig; its SHA256 is
f6d7248ff6d0d1f5cac17256f3a6f45627443e66da3fb794567391c54d8c1b40.
The workspace driver src/.review_sol_20261029.zig was removed after the checks.
No implementation, test, export, existing documentation, git commit, push,
tag or release was changed. Boat J remains running for root cleanup.

Limits: source review and finite test inputs do not prove security or cover
all buffer layouts or integer values. The2^48 OCB boundary was checked through
validate and the L schedule, not a petabyte allocation. Lifetime budgets,
nonce uniqueness, independent key derivation and input stability during two-pass
open remain caller obligations. The two long official TLS examples print only
prefixes/suffixes; their full MACs and every published ciphertext byte are
checked, while full-output evidence for longer data comes from independent
references. RFC9337 supplies PBKDF2 examples, not official cipher-composition
vectors. Generic OCB permits an empty nonce; the named AES profiles do not,
and no registered Kuznyechik OCB profile or published Kuznyechik OCB KAT is
claimed. No bit-string API, full TLS/PBES2 implementation, concurrent-mutation
safety, benchmark result or physical-optimality conclusion is established here.
