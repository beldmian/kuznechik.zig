# Cipher modes

The library provides ECB, CTR, CBC, full-block CFB, OFB, CMAC/OMAC, GCM, CCM, MGM, OCB,
the seven RFC 8645 internal modes, RFC 9189/9337 cipher compositions, and
RFC 9367/9227 MGM cipher profiles through
`@import("kuznechik").modes`. All operate in place on byte slices without allocation
and accept unaligned message buffers. Existing block APIs and Cipher layout are
unchanged.

| Interface | Initialization | Processing |
|---|---|---|
| `ecbEncrypt` / `ecbDecrypt` | `&cipher` | `try ...(cipher, data)`; complete blocks |
| `Ctr` | `.init(cipher, nonce8)` | `try context.xor(data)` |
| `Cbc` | `.init(cipher, iv16)` | `try context.encrypt(data)` / `decrypt(data)`; complete blocks |
| `Cfb` | `.init(cipher, iv16)` | `context.encrypt(data)` / `decrypt(data)` |
| `Ofb` | `.init(cipher, iv16)` | `context.xor(data)` |
| `Cmac` | `.init(cipher)` | `.update(data)`, `.final()` returns 16 bytes; `.verify(tag)` |
| `Gcm` | `&cipher`, nonce12 | `try .seal(cipher, nonce, aad, data)` returns a 16-byte tag; `.open(..., tag)` |
| `Ccm` | `&cipher`, nonce12 | `try .seal(cipher, nonce, aad, data)` returns a 16-byte tag; `.open(..., tag)` |
| `Mgm` | `&cipher`, nonce16 | `try .seal(cipher, nonce, aad, data)` returns a 16-byte tag; `.open(..., tag)` |
| `Ocb` | `&cipher`, nonce slice | `try .seal(cipher, nonce, aad, data)` returns a 16-byte tag; `.open(..., tag)` |

CTR uses the nonce as the high bytes of a big-endian counter block and starts
the low counter at zero. `CtrWithCounter(bits)` supports 32–96 counter bits in
byte steps, with a nonce of `(128-bits)/8` bytes and the RFC 8645 half-counter
message limit. It rejects exhaustion before modifying data; unused bytes from
the last generated block remain available across updates.

`CbcWithIv(blocks)`, `CfbWithIv(blocks)`, and `OfbWithIv(blocks)` use an IV register
of the specified positive number of blocks. CFB uses 128-bit feedback segments.
Keep the context for successive fragments of the same message. ECB and CBC do
not select or add a padding convention.

Version 0.9.2 batches independent CBC encryption lanes for IV registers of at
least 64 blocks. CFB encryption batches power-of-two register sizes of at least
64 blocks; other sizes retain scalar encryption. Updates shorter than 64 bytes
keep scalar paths. Both preserve the same complete context state across calls,
and CBC validates block length before any writes. Default one-block IV behavior
is unchanged. See [feedback batching evidence](performance/2026-10-29/feedback-batching/RESULTS.md)
for measured widths, short-call controls, rejected candidates and limits.

Version 0.9.3 additionally batches CBC IV widths 2/3/4/8/16/24/31/32/63.
Calls enter the helper at 128 bytes for IV2, 48 bytes for IV3 and 64 bytes
for the remaining listed widths. Other medium widths keep scalar encryption.
The scratch buffer holds at most min(64, IV blocks) blocks. Medium CFB
encryption remains scalar after its candidates failed short-call controls.
See [medium-register measurements](performance/2026-10-29/medium-feedback/RESULTS.md).

For OFB registers of at least 64 blocks, updates of at least 64 bytes use
batched XOR and register bookkeeping. Short updates keep the scalar loop;
both paths preserve the same partial keystream and context state. See
[paired integration measurements](performance/2026-10-29/ofb-core70-integration/README.md).

GCM follows the nonce/counter dimensions and conservative message bounds of
[RFC 8645 §6.2.3](https://www.rfc-editor.org/rfc/rfc8645.html#section-6.2.3).
`GcmWithCounter(bits)` supports 32–64 counter bits in byte steps. Full-tag
`seal` / `open` use 16 bytes. `sealDetached` / `openDetached` accept tag sizes
4, 8, and 12–16 bytes. Tag comparison runs in constant time before any
plaintext is written; a rejected tag leaves the ciphertext unchanged.
AAD and mutable payload slices must be disjoint. Detached output tags must also
be disjoint from both. GCM rejects overlaps before modifying any buffer; adjacent
slices of the same packet buffer are supported.

Version 0.5.0 adds [RFC 3610 CCM](https://www.rfc-editor.org/rfc/rfc3610.html).
`Ccm` uses a three-byte length field and a 12-byte nonce, with payloads smaller
than 16 MiB. `CcmWithLength(L)` supports L=2..8 and a nonce of 15-L bytes;
payload length must be smaller than `2^(8*L)` bytes. Full-tag `seal` / `open`
use 16 bytes. Detached APIs accept 4, 6, 8, 10, 12, 14, or 16 bytes. CCM encodes
tag size into authentication, so a shorter tag is not a prefix of a longer one.
Select a fixed tag size for the protocol. AAD must contain fewer than `2^64` bytes.
Each call is checked against the RFC's `2^61` block-cipher-call limit, counting
both counter passes during opening. `validate` and `validateOpen` expose the
respective length checks without processing buffers. Callers
must also enforce that cumulative limit across messages under a key.

CCM encrypts counters in batches while its CBC-MAC remains serial. Opening
authenticates privately in batches, then repeats the counter pass to write
plaintext only after verification. It uses bounded stack storage without
allocation. A failed tag leaves ciphertext unchanged. CCM applies the same
overlap checks as GCM, and both authenticated APIs are one-shot.

Version 0.6.0 adds [RFC 9058 MGM](https://www.rfc-editor.org/rfc/rfc9058.html).
Its nonce is 16 bytes with the most significant bit clear, and must be unique
under the key. The combined AAD/payload must be nonempty and contain fewer than
`2^64` bits; an empty payload with nonempty AAD is supported. Full-tag `seal` /
`open` use 16 bytes; detached APIs accept every byte length from 4 through 16.
The protocol must fix that tag length. `validate(nonce, aad_len, data_len)`
checks public dimensions without processing buffers. MGM is one-shot, verifies
before writing plaintext, and applies the same overlap rules as GCM.

MGM batches independent encryption and authentication counters, combining them
for short messages. On x86-64 with PCLMUL, authentication accumulates unreduced
carryless products and reduces once; other targets use portable multiplication.
This selection is compile-time, just like the block cipher backend.

Version 0.9.0 adds `Mgm.sealParts(cipher, nonce16, aad_parts, data)` and
`Mgm.openParts(cipher, nonce16, aad_parts, data, tag)` for `[]const []const u8`
AAD. They authenticate the concatenation with one final padding, return/accept
a full 16-byte tag for sealing and a 4–16-byte tag slice for opening,
and reject writable aliases before writes. For a shorter protocol tag,
transmit the fixed-length prefix of the returned array.

The same release exposes `Tls13MgmL`, `Tls13MgmS`, `EspMgmKtree`,
`EspMgmMacKtree`, and `IkeMgmKtree`, also grouped under `MgmProfiles`.
These accept a borrowed cipher initialized with the caller-derived record or
leaf key. `KtreeIv`, `KtreeKeyMaterial`, `EspHeader`, `EspSequence`, and `IkeAad`
provide checked metadata. TLS tags are 16 bytes; ESP/IKE tags are 12 bytes.
See [profile signatures, formatting rules, limits and external dependencies](mgm-profiles.md).

Nonce values must be unique for each message encrypted under a given key.
Starting a fresh context for a fragment resets its counter; continue the existing
context instead. These APIs do not construct TLS/IKE records or manage nonces
for callers.
CBC and CFB require unpredictable IVs. OFB requires an IV that is unique under
its key; it does not require unpredictability.

The generic algorithms are tested using the published AES vectors in
[RFC 3602](https://www.rfc-editor.org/rfc/rfc3602.html),
[RFC 4493](https://www.rfc-editor.org/rfc/rfc4493.html),
[RFC 8645](https://www.rfc-editor.org/rfc/rfc8645.html), and
[NIST SP 800-38A](https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38a.pdf).
GCM also has differential tests against Zig's AES-GCM. The same factories are
instantiated with Kuznechik, whose block primitive is independently checked
against RFC 7801. Kuznechik mode tests cover streaming splits and lengths that
cross the 64-block batch boundary. These checks are separate from sustained fuzzing.

CCM passes all 24 RFC 3610 AES packet vectors and 49 independent Node/OpenSSL
fixtures spanning every supported nonce and tag size, partial blocks, the
64-block batch boundary, and the 0xff00-byte AAD encoding transition.
Run `node scripts/ccm-oracle.cjs` to regenerate its checked-in oracle data.

MGM passes both RFC Kuznechik examples and a SHA-256 digest of 1,688 complete
AES/Kuznechik ciphertext-and-tag cases generated with an independent Go library.
Its portable and PCLMUL products also match a polynomial long-division reference.
Reference provenance and Boat measurements are in [MGM evidence](performance/modes/mgm/README.md).

Version 0.7.0 adds every internal mode from [RFC 8645 §§6.2–6.3](https://www.rfc-editor.org/rfc/rfc8645.html#section-6.2).
All section sizes `N` and master derivation lifetimes `T*` below are **bytes**;
the RFC expresses them in bits. Each stream context owns expanded keys.

| Interface | Initialization | Processing |
|---|---|---|
| `CtrAcpkm` | `try .init(cipher, nonce8, N)` | `try .xor(data)` |
| `CtrAcpkmMaster` | `try .init(cipher, nonce8, N, T)` | `try .xor(data)` |
| `GcmAcpkm` | `try .init(cipher, N)` | `try .seal(nonce12, aad, data)`; `.open(nonce12, aad, data, tag16)` |
| `GcmAcpkmMaster` | `try .init(cipher, N, T)` | Same GCM configuration methods |
| `CbcAcpkmMaster` | `try .init(cipher, iv16, N, T)` | `try .encrypt(data)` / `.decrypt(data)`; complete blocks |
| `CfbAcpkmMaster` | `try .init(cipher, iv16, N, T)` | `try .encrypt(data)` / `.decrypt(data)`; full-block feedback |
| `OmacAcpkmMaster` | `try .init(cipher, N, T)` | `try .update(data)`, `.final()` returns tag16; `try .verify(tag)` |

`N` must be positive and divisible by 16. `T` must be positive and divisible by
16 and the section material width: 32 bytes for encryption modes, 48 for
OMAC-Master's key plus finalization subkey. `acpkm(cipher)` derives the next
expanded key. `AcpkmMaster.init(cipher, T, material_bytes)` exposes the derivation
stream; `try .derive(output)` requires whole materials. Callers select section
sizes and lifetime policy appropriate to their protocol.

`CtrAcpkmWithCounter(bits)` and `CtrAcpkmMasterWithCounter(bits)` accept 32–96
counter bits in byte steps; their nonce is `(128-bits)/8` bytes. Non-master CTR
permits at most `2^(bits-1)` blocks, while master CTR permits `2^bits` blocks.
Cached gamma bytes remain usable at exhaustion. `GcmAcpkmWithCounter(bits)` and
`GcmAcpkmMasterWithCounter(bits)` accept 32–64 bits, reserving two counters from
the respective ranges. Both AAD and payload bit lengths must fit `u64`.

Master message limits additionally ensure that complete section materials fit
within `16 * 2^63` derivation bytes. GCM authentication uses the initial payload
key (the first derived key in master mode), throughout the message. GCM
configuration objects are reusable across messages with distinct nonces; their
AEAD calls are one-shot. Detached tags and overlap rules match plain GCM.

Streaming CTR, CBC, CFB and OMAC preserve state across sections and updates;
CBC updates require complete blocks. OMAC finalization is a snapshot, so it may
be repeated and followed by further updates. Verification accepts 1–16-byte
prefixes; the protocol must fix a tag length. Complete updates are checked before
changing data or context. Empty updates are no-ops. CBC/CFB require unpredictable
IVs; CTR/GCM require non-repeating nonces. These APIs do not manage key usage
across independent contexts or implement external hash-based RFC key schedules.

All Appendix A.2 section keys/materials, ciphertexts and tags are checked. The
GCM-Master example's specified 192-bit key is tested using a test-only AES-192
adapter, also checked against FIPS 197. Other vectors use AES-128/AES-256.
Kuznechik is independently compared to a scalar construction across sections,
partial updates, snapshot finalization, limits and rejections.
See [ACPKM performance evidence](performance/modes/acpkm/README.md).

Version 0.8.0 adds generic [RFC 7253 OCB](https://www.rfc-editor.org/rfc/rfc7253.html).
`Ocb` uses a 16-byte tag; `OcbWithTag(bytes)` fixes a positive byte tag of 1–16
bytes in the type, including detached APIs. Keep one tag size per key. Nonces
are slices of 0–15 bytes and must not repeat under a key, including an empty
nonce. The generic construction permits that empty nonce; the named AES profiles
require 1–15 bytes and do not assign a Kuznechik registry profile.

OCB supports empty AAD/payload and partial blocks. It batches independent block
encryption/decryption, authenticates private plaintext, then decrypts again into
the caller's buffer on success. `validate(nonce_len, aad_len, data_len, tag_len)`
checks dimensions and the per-call bound
`ceil(aad_len/16) + ceil(data_len/16) <= 2^48`. Callers must also enforce that
recommended data-block budget across messages under the key. Writable payload
must be disjoint from nonce, AAD, tag and cipher storage; an output tag must also
be disjoint from the read inputs and cipher storage. Read-only sharing is allowed.
Keep inputs stable during both passes. OCB is one-shot and allocation-free.

OCB passes all 17 Appendix A AES tuples and nine aggregate checksums, 394
Node/OpenSSL cases, and 2,208 guarded Kuznechik alignment/boundary cases.
AES vectors validate the generic construction; no Kuznechik-specific OCB registry
assignment or official Kuznechik OCB test vector is claimed. See
[OCB evidence](performance/modes/ocb/README.md).

Version 0.9.1 initializes only the OCB offset schedule entries reachable by the
full-block AAD or payload counts. Empty and partial-only messages need no L_i
entries; the inclusive L48 endpoint and bounded storage remain supported.
It adds 280 independent OpenSSL boundary cases. See the
[setup performance report](performance/2026-10-29/ocb-schedule/report.md) for
paired results, controls, large-call costs and reproduction commands.

Version 0.8.0 also adds three allocation-free compositions with independently
derived ENC/MAC ciphers. All use a fixed encrypted 16-byte tag; this tag is part
of the encrypted stream, rather than a detached AEAD tag.

| Interface | Initialization | Protection / recovery |
|---|---|---|
| `KExp15` | `.init(enc_cipher, mac_cipher)` | `try .seal(iv8, output, secret)` / `.open(iv8, output, wrapped)` |
| `TlsCtrOmac` | `.init(enc_cipher, mac_cipher)` | `try .seal(base_iv8, record, output, plaintext)` / `.open(base_iv8, record, output, ciphertext)` |
| `CtrAcpkmOmac` | `try .init(enc_cipher, mac_cipher, section_bytes)` | `try .seal(nonce8, output, plaintext)` / `.open(nonce8, output, ciphertext)` |

Out-of-place outputs must be exactly payload length plus 16 for sealing and
ciphertext length minus 16 for opening, and be disjoint from inputs and context.
`wrappedLength` / `protectedLength` check expansion. Explicit `sealInPlace` and
`openInPlace` instead operate on payload plus 16 bytes in the same buffer;
successful opening returns the plaintext prefix and preserves the encrypted-tag
suffix. Failed validation or authentication preserves all caller buffers.

KExp15 authenticates `IV || secret` and uses ordinary CTR over `secret || tag`.
TLS authenticates the exact sequence/type/version/plaintext-length metadata,
uses `(base_iv + sequence) mod 2^64`, and fixes ACPKM sections to 4096 bytes.
`TlsRecord` supplies sequence, content type and two-byte version; its plaintext
length is inferred. The output is only the encrypted record fragment. The caller
enforces compression and protocol limits and supplies TLSTREE-derived keys.
RFC 9337's cipher layer authenticates plaintext and encrypts plaintext plus tag
using the selected ACPKM section size. `nonceFromUkm` extracts UKM's first eight
bytes; the remaining bytes are for the external key-derivation seed.

These APIs implement neither full TLS nor PBES2. TLSTREE, HMAC-Streebog, PBKDF2,
KDF_TREE, key independence, nonce management, and serialization remain caller
dependencies. Exact signatures, limits and genuine RFC vector provenance are in
[composition notes](composition-notes.md). Independent review reports for
[OCB/compositions](reviews/ocb-compositions-independent-sol-20261029.md) and
[MGM/ACPKM](reviews/mgm-acpkm-independent-sol-20261029-0835.md) record their bounded
checks and limitations.
