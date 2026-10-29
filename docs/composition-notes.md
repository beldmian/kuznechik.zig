# Reusable RFC 9189 and RFC 9337 compositions

`src/modes/compositions.zig` implements three allocation-free MAC-then-encrypt
constructions for 128-bit block ciphers with 256-bit keys. The genuine
Kuznyechik known answers below establish the relevant RFC 9189 formatting.
A generic instantiation with another cipher is not a claim that an RFC specifies
that cipher suite. This module does not implement TLS, IKE, or PBES2.

## Integration and API

Version 0.8.0 exports `modes.KExp15`, `modes.TlsCtrOmac`, and
`modes.CtrAcpkmOmac`; `modes.TlsRecord` is the record-metadata type.
The following generic factories are also available in the implementation module. Given `Classic = classic.Modes(Cipher)` and
`Acpkm = acpkm.Modes(Cipher, Classic)`, instantiate:

```zig
const Compositions = @import("compositions.zig").Modes(Cipher, Classic, Acpkm);
// Compositions.KExp15, Compositions.TlsCtrOmac, Compositions.CtrAcpkmOmac
```

The standalone factories are `KeyWrap(Cipher, Classic)`,
`TlsRecord(Cipher, Classic, Acpkm.CtrAcpkm)`, and
`PasswordComposition(Cipher, Classic, Acpkm.CtrAcpkm)`. In particular, the
standalone key-wrap factory has no ACPKM dependency. The ACPKM parameter is the
completed non-master 64-bit-counter stream with
`init(cipher, nonce8, section_bytes)`, `validate(length)`, and `xor(data)`.

Each context owns two caller-provided, expanded ciphers. `init(encryption,
authentication)` uses that argument order, also for KExp15 (whose RFC pseudocode
lists the MAC key first). The caller must supply independently derived keys;
this API cannot prove key independence. RFC 9337 additionally requires a
positive `section_bytes` divisible by 16 at initialization. TLS fixes this
value at 4096 bytes.

All three have `seal`, `open`, `sealInPlace`, and `openInPlace`. Out-of-place
`seal` takes an output slice of exactly `plaintext.len + 16`; `open` takes an
output slice of exactly `ciphertext.len - 16`. `wrappedLength` (KExp15) and
`protectedLength` (the other two) perform checked length calculations.
All output/input overlap is rejected, including exact aliasing and overlap
only with the encrypted tag. Adjacent slices are legal. Explicit in-place
operations use a buffer containing the payload followed by 16 writable bytes.
`openInPlace` returns the plaintext prefix and leaves the encrypted tag suffix
intact. Buffers may start at any byte alignment.

All input errors and failed authentication preserve both input and output.
Opening first decrypts into a private 1024-byte scratch buffer, feeds the exact
plaintext into CMAC, privately decrypts the tag at its actual stream offset,
and compares all 16 bytes with `std.crypto.timing_safe.eql`. Only successful
verification starts a fresh stream and writes the plaintext. The private
scratch and received tag are explicitly cleared. This is bounded private
storage, not allocation or a message-sized staging buffer. It is not a claim
of complete key/register erasure or whole-program constant-time behavior;
raw-cipher timing properties are inherited.

## Exact construction rules

KExp15/KImp15 implement [RFC 9189 section 8.2.1](https://www.rfc-editor.org/rfc/rfc9189.html#section-8.2.1):
OMAC authenticates `IV8 || secret`; ordinary CTR encrypts `secret || OMAC16`.
The initial counter block is `IV8 || 0^64`, the rightmost 64 bits increment
big endian, and neither the counter nor IV is reset before encrypting the
MAC. There is no ACPKM here. Empty secrets are supported; imports shorter than
16 bytes are rejected. IVs must be unique under each ENC/MAC key pair.

TLS implements [RFC 9189 sections 4.1.1, 4.3.2, and 4.3.3](https://www.rfc-editor.org/rfc/rfc9189.html#section-4.1.1):
OMAC authenticates `seqnum_be64 || type_u8 || version_2bytes || length_be16 ||
TLSCompressed.fragment`. The API's `Record` supplies sequence, content type,
and version; the authenticated length is calculated from the plaintext slice.
CTR-ACPKM encrypts `fragment || OMAC16`, with a 4096-byte section size over the
**combined** plaintext-and-tag stream. The counter starts at
`IV_seqnum || 0^64`, where `IV_seqnum = (INT(sender_write_IV) + seqnum) mod 2^64`.
`recordIv` exposes this exact big-endian addition.

The TLS methods take `(sender_write_IV, Record, ...)` and return only the
`TLSCiphertext.fragment`. A five-byte TLS wire header is not part of the output.
A packet-specific helper accurately expresses these authenticated bytes;
arbitrary AAD would let callers choose an incorrect order or authenticate the
ciphertext length instead of the compressed plaintext length. This is not an
encrypt-then-MAC construction, and its encrypted tag is not a detached AEAD tag.

RFC 9337's OMAC variant implements the cipher layer of
[sections 5.1.1 and 5.1.2](https://www.rfc-editor.org/rfc/rfc9337.html#section-5.1.1):
OMAC authenticates **only plaintext**, and CTR-ACPKM encrypts `plaintext ||
OMAC16`, with the protocol-selected section size over that combined stream.
The nonce argument is `ukm[0..8]`; `nonceFromUkm(ukm16)` extracts it explicitly.
The last eight UKM bytes are a key-derivation seed, not an extra MAC prefix or
counter suffix. This construction does not authenticate a TLS header or the
IV directly. The independent MAC and ENC keys and unique nonce remain essential.

The initial counter and subsequent counter progression are the same in all
three: prefix the eight-byte nonce and increment the low 64 bits. At ACPKM
section boundaries only the encryption key changes; counters continue and
OMAC retains its original independent key. The whole encrypted stream,
including the tag, is preflighted against the underlying non-master CTR
budget of `ceil((plaintext_bytes + 16)/16) <= 2^63`. For KExp15 this is the
released ordinary CTR's conservative library profile, rather than a separate
normative KExp15 limit; it does not further constrain addressable byte slices
on the supported 32/64-bit targets. Checked `usize` expansion also limits
representable buffers. No allocation or huge synthetic slices are
used to bypass those checks. The public factories intentionally use the
64-bit counter profile, not a generalized counter width or master construction.

## Profile responsibilities outside this module

- TLS initialization requires the per-record ENC and MAC keys from TLSTREE,
  not connection root keys. TLSTREE and its HMAC-Streebog KDF, connection state,
  record sequence progression/replay prevention, compression, framing, and
  handshake are not implemented here. Sequence is `u64`, covering RFC 9189's
  Kuznyechik SNMAX. The helper authenticates type/version verbatim; the TLS
  layer validates their meanings. The helper enforces the
  [RFC 5246 section 6.2.2](https://www.rfc-editor.org/rfc/rfc5246.html#section-6.2.2)
  TLSCompressed fragment bound of 17408 bytes. With null compression, the
  caller enforces TLSPlaintext's smaller 16384-byte bound.
- RFC 9337 requires PBKDF2 with HMAC-Streebog, producing DK32; its PBES2 OMAC
  variant then derives K(1)=ENC and K(2)=MAC using
  `KDF_TREE_GOSTR3411_2012_256(DK, label="kdf tree", seed=ukm[8..16], R=1)`.
  These are caller dependencies, not replaced with ACPKM or another hash.
  Salt selection (8..32 bytes), iteration count (at least 1000), unique salt
  and UKM, and ASN.1/OID serialization remain outside the bare cipher layer.
  The module accepts derived keys and the nonce, not passwords, DK, or ASN.1.
- KExp key derivation (including KEG/VKO where used), independent key selection,
  IV transport, and protocol representation/serialization are caller duties.
  A library stateless context cannot enforce cross-message nonce uniqueness,
  aggregate key lifetime, or key independence.

## Reproducible correctness evidence

`src/composition_tests.zig` is a non-hidden standalone driver. It imports only
composition tests directly; their cipher/mode dependencies also run their own
embedded tests. No temporary hidden drivers or VM artifacts are required.
Using local Zig 0.15.1:

```sh
/tmp/kuz-toolchains/zig-x86_64-linux-0.15.1/zig test src/composition_tests.zig -O Debug -mcpu native
/tmp/kuz-toolchains/zig-x86_64-linux-0.15.1/zig test src/composition_tests.zig -O ReleaseSafe -mcpu native
/tmp/kuz-toolchains/zig-x86_64-linux-0.15.1/zig test src/composition_tests.zig -O ReleaseFast -mcpu native
```

The official examples are genuine Kuznyechik:

- [RFC 9189 A.1.3.2](https://www.rfc-editor.org/rfc/rfc9189.html#appendix-A.1.3.2):
  the complete 32-byte PMS and 48-byte PMSEXP, the two published export keys,
  and IV `214a6a298e99e325`. Both export and import match exactly.
- [RFC 9189 A.1.2.2](https://www.rfc-editor.org/rfc/rfc9189.html#appendix-A.1.2.2):
  records with sequence 0/63/64, lengths 15/4096/8192, and the published
  **already TLSTREE-derived** per-record keys. The complete sequence-0
  ciphertext matches. For the two longer records, the RFC elides the middle:
  every printed fragment byte is compared (43-byte prefix and 53-byte suffix),
  and all three full MAC intermediates match. These tests do not claim to
  validate TLSTREE itself or nonexistent full published long-record bytes.

`src/modes/composition_reference.py` implements independent scalar CMAC,
CTR, ACPKM, and composition formatting in Python, using only the raw block
cipher from [gostcrypto 1.2.5](https://pypi.org/project/gostcrypto/1.2.5/)
([upstream source](https://github.com/drobotun/gostcrypto)). Its wheel SHA256 is
`5cfc8b4c33d2a110fea0cfcb693b4a5f2b021004b9cf8d6bba8b78aab23d2001`.
The generator checks the official PMS export and sequence-0 TLS record before
producing fixtures. The fixture generator does not call Zig or this repository's
mode implementations. With that package on `PYTHONPATH`, regenerate with:

```sh
python3 src/modes/composition_reference.py
zig fmt src/modes/composition_oracle.zig
```

The corpus stores **complete ciphertexts**, not just round trips or hashes:
162 cases, 440262 bytes in `composition_oracle.bin`, SHA256
`d4aede6123195bb246e09efb600e8625915a4aa67467dd96ff6bef50b6468526`.
`composition_oracle.zig` gives each case's offset, size, parameters and SHA256.
Public test inputs are ENC bytes 0..31, MAC bytes 32..63, nonce bytes 0..7,
and payload byte `i = (29*i+7) mod 256`. TLS uses sequence `2^64-1` to also
exercise modulo IV addition. Password compositions use sections 16/32/1024/4096.
Each family covers lengths 0,1,15,16,17,31,32,33,63,64,65,1007,1008,1009,
1023,1024,1025,4079,4080,4081,4095,4096,4097,8191,8192,8193,17408.
These cases cover payload/tag transitions across both batch and section
boundaries. They are independent reference vectors, **not official RFC 9337
cipher vectors**: that RFC's Appendix A contains PBKDF2 vectors only.

The suite compares every full corpus output at all 16 alignment offsets,
using caller-owned output buffers and explicit in-place APIs, with guard bytes.
It tests private authentication and preservation after every byte corruption
for small cases and boundary-selected corruptions for large cases; wrong
ENC/MAC keys, nonce, record metadata and section sizes; truncation/extension
by 1..16 bytes; all short input lengths; output-size mismatches; overlapping
slices in both address orders; adjacent slices; invalid sections; TLS limits;
`usize` expansion overflow; and a constrained stream adapter that confirms
preflight includes the encrypted tag before any caller buffer is written.

Final native runs on 2026-10-29, Zig 0.15.1, x86_64 KVM executor reporting
Intel Xeon E5-2690 v4 (Broadwell, AVX2/AES, no GFNI): **56 passed, 2 skipped,
0 failed in each of Debug, ReleaseSafe and ReleaseFast**. All seven
composition-specific tests passed. The two skips are the existing raw-cipher
GFNI instruction tests, unavailable on this executor; they are not skipped
composition coverage. `zig fmt --check` also passes for all composition Zig
files. Regenerating the independent fixture corpus reproduced its exact
440262-byte content and SHA256 above.

No composition performance measurement or Boat VM was needed, and no speed
or physical-optimality claim is made. The implementation retains the released
CTR/CTR-ACPKM batch paths; OMAC itself retains its serial dependency.
