# Cipher modes

The library provides ECB, CTR, CBC, full-block CFB, OFB, CMAC/OMAC, GCM, CCM, and MGM through
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

CTR uses the nonce as the high bytes of a big-endian counter block and starts
the low counter at zero. `CtrWithCounter(bits)` supports 32–96 counter bits in
byte steps, with a nonce of `(128-bits)/8` bytes and the RFC 8645 half-counter
message limit. It rejects exhaustion before modifying data; unused bytes from
the last generated block remain available across updates.

`CbcWithIv(blocks)`, `CfbWithIv(blocks)`, and `OfbWithIv(blocks)` use an IV register
of the specified positive number of blocks. CFB uses 128-bit feedback segments.
Keep the context for successive fragments of the same message. ECB and CBC do
not select or add a padding convention.

GCM follows the nonce/counter dimensions and conservative message bounds of
[RFC 8645 §6.2.3](https://www.rfc-editor.org/rfc/rfc8645.html#section-6.2.3).
`GcmWithCounter(bits)` supports 32–64 counter bits in byte steps. Full-tag
`seal` / `open` use 16 bytes. `sealDetached` / `openDetached` accept tag sizes
4, 8, and 12–16 bytes. Authentication verifies in constant time before any
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

RFC 8645 ACPKM/ACPKM-Master constructions are being integrated in a later increment.
