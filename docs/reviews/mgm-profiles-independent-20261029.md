# Independent MGM profile review — 2026-10-29

**Finding: one P2 correctness defect in the newly added raw multipart API.**
Fix the nonce capture in `Mgm.sealParts` before integrating it. No additional
crypto/semantic defect was found in the reviewed TLS, ESP or IKE profile code.
This is an executed review, not a formal proof or a complete protocol audit.

Reviewed commit: `b755749cfac5c820bf8d922a9957185865872271`, author worktree
`/home/t3/.t3/worktrees/kuznechik.zig/t3-7d31553c`.
The author worktree and root source were not modified. The only repository write
is this new report. No commits, pushes, tags, releases, exports, versions,
README, CHANGELOG or OpenSpec changes were made.

## P2: sealParts rereads a payload-aliased nonce after encryption

Location: `src/modes/mgm.zig:82–83` in the reviewed commit, inside
`Mgm.sealParts` (function begins at line 77).

A nonce supplied as the value `data[0..16].*` is accepted. In optimized Zig
0.15.1 builds, that aggregate argument can retain the caller's backing storage.
`xor(cipher, nonce, data)` encrypts the backing bytes, then
`authenticateParts(cipher, nonce, ...)` reads the changed bytes as a different
nonce. Encryption returns the correct ciphertext with the wrong tag. Opening
with the original key, nonce and AAD fails with `AuthenticationFailed`.

Concrete input: key = 32 copies of `71`, nonce = 16 copies of `4b`, AAD = `01`,
plaintext = 64 copies of `4b`. Compare these two calls on separate initially
identical buffers:

```zig
const expected = try M.sealParts(&cipher, @splat(0x4b), &.{&.{1}}, &reference);
const actual = try M.sealParts(&cipher, aliased[0..16].*, &.{&.{1}}, &aliased);
```

Expected tag: `98cffa8005f2a24b96326d2ce0001ae6`.
Actual aliased tag: `5e410edaba74a3895c04368fe67194aa`.
The ciphertexts are identical. The expected tag was also calculated by this
review's separate Python MGM implementation, using schoolbook carryless
multiplication followed by polynomial long division.

Reproducer: `/home/t3/mgm-profiles-review-20261029/branch/src/review_nonce_alias.zig`.
From that staging directory:

```sh
/tmp/kuz-toolchains/zig-x86_64-linux-0.15.1/zig run src/review_nonce_alias.zig -O ReleaseSafe --cache-dir /home/t3/.cache/mgm-independent-20261029-portable-local --global-cache-dir /home/t3/.cache/mgm-independent-20261029-portable-global
```

It exits 1 after printing the two tags, equal ciphertexts and failed opening.
The same defect reproduced on Boat J core 0 with `-mcpu=native`, in both
ReleaseSafe and ReleaseFast, on both the original branch and the current-main
integration staging copy. The portable Debug reproducer passes; this is an
optimization-sensitive alias defect, not a claim that every build fails.

Primary expected behavior: [RFC 9058 section 4.1](https://www.rfc-editor.org/rfc/rfc9058.html#section-4.1)
uses the same ICN for encryption's `E_K(0 || ICN)` and authentication's
`E_K(1 || ICN)`. The documented memory contract excludes payload overlap with
AAD, tags and the borrowed Cipher, and says value metadata is captured before
processing; it does not forbid this value-nonce layout. These calls therefore
must compute the same result, or an explicitly unsupported alias must be
rejected before writing. The current accepted call silently returns an
unusable authenticated message.

Minimal fix: explicitly copy the nonce into stable local storage before the
first payload write and use that copy for both phases:

```zig
var captured_nonce: [16]u8 = undefined;
@memcpy(&captured_nonce, &nonce);
xor(cipher, captured_nonce, data);
return authenticateParts(cipher, captured_nonce, aad, length, data);
```

A staging-only candidate is preserved as `branch/src/modes/review_mgm_fix.zig`,
with `evidence/proposed-nonce-capture.patch` and
`branch/src/review_nonce_alias_fix.zig`. It makes the reproducer pass locally
in ReleaseSafe and on Boat in ReleaseSafe and ReleaseFast. The candidate was
not applied to the author branch and has not received a full regression run.
Add this layout as a regression case in the eventual fix.

The profile wrappers form their nonce before invoking raw MGM. Separate tests
of TLS L/S write-IV values and ESP salt values backed by the payload passed
on portable and Boat ReleaseSafe. The reported defect is scoped to the new
raw multipart sealing API; no profile-wrapper failure was observed.

## Executed checks

All source runs used Zig 0.15.1. Both compiler binaries have SHA256
`0ee27482eb2e7b19fad58579c107364aa93fbfb54be2d2b9c52cef5f955d6225`.
Local caches were newly assigned under `/home/t3/.cache/mgm-independent-20261029-*`;
Boat caches under `/home/user/.cache/mgm-independent-20261029-native-*`.
Both filesystems are ext4, not `/tmp` tmpfs. No obsolete 27-test result was
accepted: every test name and ordinal was parsed and retained in
`evidence/executed-test-inventory.json`.

Original branch:

- Portable ReleaseSafe and Debug: 85 actual tests each, 83 pass and 2 GFNI skips.
- Boat J `bx_4bnay2nf`, AMD Ryzen 9 9950X, exclusive core 0, native
  ReleaseSafe and ReleaseFast: 91/91 pass each.

Integration staging copy:

- Source-only archive of current main `40f77f43fd964a8ac528bf686ce7c1cda859424d`
  (v0.8.1, retained 70-map GFNI core), overlaid with the six profile/API/test
  files listed in the retained command record. Root exports were not wired.
- Portable ReleaseSafe: 83 pass plus 2 GFNI skips out of 85.
- Boat native ReleaseSafe and ReleaseFast: 91/91 pass each.
- Cipher size remains 352 bytes.

Independent driver, **in addition to** the shipped suite:

- 111 deterministic fresh-key cases, with distinct keys/metadata generated
  using SHAKE256. A separate Python MGM oracle uses only gostcrypto 1.2.5 raw
  Kuznyechik encryption; counter construction, profile formatting, full
  carryless multiplication and polynomial long division are review code.
- Complete ciphertext/tag comparisons for raw MGM, TLS L/S, ESP SN/ESN,
  MAC-only SN/ESN, IKE ordinary and fragmented AAD. Data lengths include
  0, 1, 15, 16, 17, 463, 464, 465, 1023, 1024, 1025 and 2049 where valid.
- 318 multipart layouts against the independently concatenated oracle AAD:
  splits and fixed chunks around 16/1024, repeated empty parts, one-byte
  parts, total-empty AAD, empty payload, unaligned payloads and guard bytes.
  These comparisons exercise one AAD padding domain, a separate ciphertext
  domain, and the final total-AAD/ciphertext bit lengths.
- 7,090 negative authentication/tag/metadata checks per final driver run,
  checking full payload preservation. These include every profile tag byte,
  wrong keys, changed nonce/IV/salt/sequence, SPI and ESN high-word changes,
  IKE header/prefix/fragment changes and ciphertext changes. All raw tag
  lengths 4 through 16 are covered in multipart failures; profile tags remain
  fixed at TLS 16 and ESP/IKE 12.
- Rejected AAD byte/payload intersections, descriptor-storage/payload
  intersections, tag/payload intersections and Cipher/payload intersections;
  checked Cipher and descriptor preservation and allowed read-only
  Cipher/body overlap for MAC-only.
- Independent checks of TLS nonce XOR/masking, headers and literal masks;
  KTREE network-order IV/seeds/nonce, KEYMAT split, pnum maximum/overflow;
  TLS sequence/length endpoints and raw high-bit nonce rejection in shipped
  tests. Leaf-index-only changes with an unchanged supplied leaf Cipher were
  not falsely treated as AEAD key-selection tests.
- Wide integer and multipart-length overflow rejection, including rejected
  synthetic descriptors. No synthetic oversized slice was accepted or
  dereferenced. Real allocated buffers tested ESP/MAC 65,508-byte body
  maxima and an IKE fragment at its exact full-wire extent, plus one-byte
  excess rejection without mutation.
- Final driver passed on both branch and integration copies locally in
  ReleaseSafe, and on Boat in ReleaseSafe and ReleaseFast. Its separate
  nonce-alias reproducer remains intentionally failing as reported above.

## Published fixtures and contract audit

Primary sources reviewed: [RFC 9367 sections 4.1–4.1.3](https://www.rfc-editor.org/rfc/rfc9367.html#section-4.1),
[RFC 9227 sections 4–5](https://www.rfc-editor.org/rfc/rfc9227.html#section-4),
[RFC 8446 sections 5.2–5.4](https://www.rfc-editor.org/rfc/rfc8446.html#section-5.2),
and [RFC 9058 section 4](https://www.rfc-editor.org/rfc/rfc9058.html#section-4).
Fresh primary RFC 9367/9227 downloads matched the worker's cached exact texts.
All four primary text snapshots are retained in review evidence.

The author generator was rerun only in staging. It reproduced the original
270,839-byte blob SHA256
`2e17c30f39114c5d15a64fca86f06eb98e661b5e657a9837f4a9f348aa910c5a`;
formatted vector source also matched the author copy. All 44 entries of the
author source manifest matched the untouched author worktree.

The separate `evidence/audit_published.py` then used this review's oracle to
check all 17 RFC 9367 A.1 records, including every byte in the 3,253 published
TLS wire-dump bytes, all 17 complete 16-byte tags, and the duplicated compact
`encrypted_record` prefixes/suffixes. It compared complete reconstructed
ciphertext/tag outputs against the stored fixtures. The eight long records
explicitly specify zero application data and padding; the omitted plaintext
ranges reconstruct as 1,024 zero bytes, type `17`, then 15,360 zero bytes.
Unpublished ciphertext interiors are independently calculated values, not
additional published known-answer bytes. All four Kuznyechik RFC 9227 examples
(1, 2, 5, 6) matched full ciphertext and ICV through the separate oracle.

No KDF provenance gap was disguised: these RFCs publish the derived record and
leaf keys. No TLSTREE/KTREE implementation is present or claimed. A.1 is the
Kuznyechik MGM_S example; using its same supplied key for L tests shared cipher
formatting, not the L key schedule. Magma examples are outside this library's
scope. IKE/fragment fixtures are synthetic reference checks, not published
RFC 9227 IKE vectors.

The code and docs correctly distinguish ESP AEAD `SPI || (E)SN` from MAC-only
`SPI || (E)SN || IV || body`, use big-endian ESN high word before low word,
and exclude IV from IKE AAD. IKE AAD follows header, unencrypted payloads,
then 4-byte encrypted or 8-byte fragment header. Extent helpers count the
specified wire fields and omit the ESN high word that is not transmitted;
outer IP limits are explicitly the caller's obligation.

The caller-derived-key boundary is explicit and consistent. HMAC-Streebog,
TLSTREE/KTREE derivation, parsing/framing, replay protection, cumulative use,
SA/key lifetime, and TLS/ESP/IKE content and padding validation remain external.
Root export wiring is deliberately deferred and is not a defect.

## Evidence and limits

All review artifacts are outside caches under
`/home/t3/mgm-profiles-review-20261029/`, including original/integration source
staging, `evidence/generate_review.py`, `evidence/audit_published.py`,
`branch/src/review_driver.zig`, generated `review_vectors.zig` and
`review_oracle.bin`, reproducers, proposed patch, compiler/source hashes,
full test logs and `boat-final-evidence/`.
The final review oracle blob is 236,858 bytes, SHA256
`ade86f6ded54849c7b9d023ab1c909dd6bd19485e4e5ae52c910a4aebfb51754`.
Earlier lowercase native `*-safe.log` driver files preserve preliminary corpus
runs; final `*-ReleaseSafe.log` / `*-ReleaseFast.log` driver logs record the
111-case, 318-layout, 7,090-negative corpus.

The Boat source-only staging directory is
`/home/user/kuz-mgm-profiles-review`; the worker's original evidence was
preserved. Only assigned Boat J was used. It was left running for root cleanup;
its recorded expiry remains 2026-10-29 10:04:40 UTC, with no extension needed.

These runs cover the stated byte-oriented cipher boundary and observed builds.
They do not establish exhaustive alias/layout coverage, independent KDF or
block-cipher proofs, complete protocol correctness, side-channel properties,
or universal performance/physical optimality. No benchmark speed conclusion
was added by this review.
