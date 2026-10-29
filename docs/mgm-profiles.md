# Kuznyechik MGM cipher profiles

`src/modes/mgm_profiles.zig` implements the cipher boundary of RFC 9367
(TLS 1.3 Kuznyechik MGM_L and MGM_S) and RFC 9227 (ESP / IKEv2
Kuznyechik MGM-KTREE, and ESP MGM-MAC-KTREE). It takes a borrowed `Cipher`
already initialized with the **derived per-record or leaf key**, not the traffic
root key. It neither derives that key nor implements TLS, ESP, or IKEv2.
There are no allocations, message-sized temporary buffers, or alignment
requirements on byte slices. `Cipher` and the existing block APIs are unchanged.

Version 0.9.0 exposes `modes.{Tls13MgmL,Tls13MgmS,EspMgmKtree,
EspMgmMacKtree,IkeMgmKtree}`, also grouped under `modes.MgmProfiles`, plus
the metadata types `KtreeIv`, `KtreeKeyMaterial`, `EspHeader`, `EspSequence`,
and `IkeAad`. Generic users can instantiate `Profiles(Cipher)` directly.

## TLS 1.3 (RFC 9367 sections 4.1–4.1.3)

```
const tag = try Tls13MgmS.seal(&record_cipher, sender_write_iv, seqnum, inner_plaintext);
try Tls13MgmS.open(&record_cipher, sender_write_iv, seqnum, ciphertext, &tag);
```

The caller derives `sender_record_write_key = TLSTREE(sender_write_key, seqnum)`
using HMAC-Streebog-256 / KDF_GOSTR3411_2012_256 (RFC 7836 section 4.5),
then initializes `record_cipher`. The external KDF applies labels `level1`,
`level2`, `level3` without NUL terminators, with the three big-endian 8-byte
masked sequence values returned by `seeds`. The masks are:

| Suite | C1 | C2 | C3 | Maximum sequence (inclusive) |
|---|---|---|---|---|
| Kuznyechik MGM_L | f800000000000000 | fffffff000000000 | ffffffffffffe000 | 2^64−1 |
| Kuznyechik MGM_S | ffffffffe0000000 | ffffffffffff0000 | fffffffffffffff8 | 2^42−1 |

The nonce is the 16-byte sender write IV XOR the sequence encoded big endian
and padded on the left with eight zero bytes. The top bit of byte zero is then
cleared. Raw MGM still rejects a set top bit; it has not adopted this masking
rule. `nonce` is a checked helper if the caller needs the formatted value.

The input is an encoded TLSInnerPlaintext including its content type and all
padding. Its size is 1 through 16385 bytes (RFC 8446 section 5.4). The five-byte
AAD is generated as `17 03 03 || uint16_be(data.len + 16)`. TLS uses a fixed
16-byte tag. The plaintext cap excludes the AAD and tag. The `header` and
`validate` helpers check lengths without creating artificial slices.

The caller manages sequence increments without wrapping, traffic secrets,
key updates, IV derivation, directional key separation, negotiated record-size
limits, handshake state, alerts, and TLSInnerPlaintext content/padding parsing.
This cipher layer permits an all-zero byte string; the TLS layer must reject
an authenticated plaintext that lacks a content type. No semantic protocol
validation is performed after plaintext is written.

## ESP / IKEv2 (RFC 9227 sections 4 and 5)

All these transforms use a fixed **12-byte** ICV (the most significant 96 bits
of the MGM tag). `KtreeKeyMaterial.split` separates a 44-byte transform key into
the first 32 bytes (the **root** key) and the final 12 bytes (the secret salt).
The salt is fixed for the SA and never transmitted. The root key is not a
message encryption key.

The caller derives the leaf key as:

```
K_msg = KDF(KDF(KDF(root_key, "level1", 00 || i1), "level2", uint16_be(i2)),
            "level3", uint16_be(i3))
```

The KDF is RFC 7836 KDF_GOSTR3411_2012_256, not a block-cipher substitute.
`KtreeIv.seeds` returns these exact seed bytes. IV serialization is
`i1[1] || i2[2] || i3[2] || pnum[3]`, with all integers in network order.
`pnum` is accepted as `u32` and checked to be at most `0xffffff` before narrowing.
The MGM nonce is **`00 || pnum[3] || salt[12]`**; the leaf indices select the
external key and do not enter the nonce. `decode` extracts IV fields without
inventing local key-selection policy. `encode`/`nonce`/`seeds` reject an out-of-range
pnum before any cipher operation.

For ESP AEAD:

```
const tag = try EspMgmKtree.seal(&leaf_cipher, salt, iv, esp_header, body);
try EspMgmKtree.open(&leaf_cipher, salt, iv, esp_header, body, &tag);
```

`EspHeader` supplies a numeric SPI and `.sn: u32` or `.esn: u64`. The AAD is
`SPI || SN` (8 bytes) or `SPI || ESN` (12 bytes), always big endian. The ESN
high word precedes its low word. The IV is not AAD for the AEAD transform.
The body contains all payload, protocol padding, Pad Length and Next Header.
Its buffer is encrypted in place. The caller supplies and checks ESP padding;
MGM itself needs no padding.

For ESP authentication only, `EspMgmMacKtree.seal/open` have the same argument
order, but the body is a **read-only** slice. AAD is exactly
`SPI || (E)SN || IV || body`. The MGM plaintext and ciphertext are empty.
No bytes of the body are encrypted, copied or modified, including on failure.
This transform is not offered for IKEv2.

For IKEv2, `IkeMgmKtree.seal/open` take `IkeAad` in place of `EspHeader`.
`IkeAad` requires a 28-byte IKE header, the serialized unencrypted payloads
(possibly empty), then `.payload: [4]u8` (Encrypted payload generic header)
or `.fragment: [8]u8` (Encrypted Fragment generic header plus Fragment Number
and Total Fragments). These fields form one AAD string in that order; the IV
is excluded. The caller supplies final header lengths and valid payload
chains. Parsing and checking those fields is the protocol layer's responsibility.
Data is the serialized protected payload including the caller's IKE padding
and Pad Length; the MGM primitive adds no protocol padding.

`validateLength` bounds the ESP extent `8-byte wire ESP header + 8-byte IV +
body + 12-byte tag` to 65536 bytes. The ESN high word is authenticated but not
transmitted, so it is not added to the wire size. Outer IP headers are outside
this cipher boundary; the caller must enforce the actual full network datagram
size, which can reduce this maximum. `IkeMgmKtree.validateLengths` bounds the
complete IKE extent `AAD + IV + payload + ICV` to 65536. Thus AAD **is counted**
in these wire bounds. They implement the 2^16-octet message boundary described
in RFC 9227 section 5, not a new per-leaf aggregate budget or a packet parser.
All counts use wide checked arithmetic, with no synthetic accepted slices.

The caller must keep each IV unique for the SA, use at most 2^24 messages
per leaf, advance the tree indices and reset pnum as specified in section 4.8,
and stop/rekey before counters wrap. A single leaf has a recommended 2^41-octet
budget for Kuznyechik (section 5); with the protocol's per-message and per-leaf
message limits, 2^40 octets is already the maximum. This stateless API does not
track cumulative use or failed verification attempts. The protocol layer also
handles KEYMAT / SK_ei / SK_er derivation, automatic keying (manual keying is
forbidden), SA/replay state, network framing, fragmentation and key erasure.
SK_ai / SK_ar are unused and zero length with these AEAD transforms.

## Authentication and memory contracts

Encryption validates lengths, sequence/counter bounds and aliases before
writing. Decryption computes and verifies the tag in private before modifying
the ciphertext; a wrong tag, key, salt, AAD or nonce preserves the buffer.
Only the specified tag length is accepted by each profile. Returned tags are
fixed-size values, so encryption has no caller-supplied tag output to alias.
Mutable payloads cannot overlap the borrowed cipher, input AAD or input tag.
Read-only inputs may overlap each other; adjacent slices are supported.
Metadata passed by value is captured before processing.

The narrowly scoped `Mgm.sealParts/openParts` helper authenticates an AAD
concatenation with **one final zero padding**, rather than padding each part.
AAD and ciphertext still have separate MGM padding domains and the final
length block encodes total AAD bits followed by ciphertext bits. It holds at
most a 16-byte pending fragment plus existing bounded block batches. It rejects
AAD descriptor storage overlapping mutable payloads. The old contiguous APIs,
raw nonce rules, polynomial implementation and vectors remain unchanged.

## Validation and provenance

Primary specifications:
[RFC 9367](https://www.rfc-editor.org/rfc/rfc9367.html),
[RFC 9227](https://www.rfc-editor.org/rfc/rfc9227.html),
[RFC 8446](https://www.rfc-editor.org/rfc/rfc8446.html), and
[RFC 9058](https://www.rfc-editor.org/rfc/rfc9058.html).
RFC text inputs remain in `docs/validation/mgm-profiles`. Commands, compiler/
hardware identities, hashes, test logs and timing samples are preserved in the
[research archive](performance/README.md).

`mgm_profiles_reference.py` uses gostcrypto 1.2.5 solely for raw Kuznyechik
block encryption. It independently implements MGM counters and polynomial
multiplication and checks every available ciphertext byte and tag from all
17 RFC 9367 A.1 Kuznyechik records and all four Kuznyechik examples in RFC 9227
Appendix A. All derived record/leaf keys are published, so no fixture KDF was
needed. The eight long TLS records omit only explicitly zero plaintext ranges;
the generator reconstructs them and checks all published wire prefixes/suffixes,
then stores complete independently calculated outputs. Magma examples are
outside this Kuznyechik library's scope. Reusing a supplied leaf key with L in
the tests checks the shared cipher algorithm, not the distinct L key schedule.
Independent synthetic fixtures are labeled separately from RFC examples.

To regenerate (with gostcrypto 1.2.5 available in Python's module path):

```
python3 src/modes/mgm_profiles_reference.py
zig fmt src/modes/mgm_profiles_vectors.zig
zig test src/mgm_profiles_tests.zig -O ReleaseSafe --cache-dir <fresh-disk-cache> --global-cache-dir <fresh-disk-global-cache>
```

Author validation: 91 native tests pass in ReleaseSafe and ReleaseFast on Boat J
(core 0); portable Debug and ReleaseSafe each pass 83 tests with two expected
GFNI skips. This includes the unchanged root suite. See
[original validation report](https://github.com/beldmian/kuznechik.zig/blob/research-2026-10-29/docs/validation/mgm-profiles/REPORT.md) for the source/compiler hashes, exact
commands, counts, hardware and timing scope. The timing harness preserves 105
samples across 15 configurations without making universal performance claims.

The independent review found one nonce-capture defect in the new raw
`Mgm.sealParts` API, corrected before v0.9.0. Final integration passes 99 native
tests in ReleaseSafe/ReleaseFast and 91 portable tests with two expected skips
in Debug/ReleaseSafe. The independent executable also passes in both native
optimized modes. See the [original review](https://github.com/beldmian/kuznechik.zig/blob/research-2026-10-29/docs/reviews/mgm-profiles-independent-20261029.md)
and [resolution and final evidence](https://github.com/beldmian/kuznechik.zig/blob/research-2026-10-29/docs/validation/v0.9.0/README.md).
