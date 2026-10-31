# RFC cipher-mode scope and conformance matrix

The audited byte-oriented mode families, compositions and cipher-profile helpers
are released through v0.9.4. This inventory records applicable constructions,
constraints, vector provenance and external protocol dependencies. The raw cipher
uses 128-bit blocks, a 256-bit key and its existing 352-byte layout. See
[mode APIs](MODES.md), [validation](validation/README.md) and
[tracked follow-ups](OPEN-WORK.md).

## Reading the matrix

Here `n = 128` and `k = 256` are **bits**, `c` is the counter width, `N` is the section size in bits, and `T*` is the master derivation stream's rekeying interval in bits. Byte APIs divide these dimensions by eight. `ceil` matters for partial blocks. A finite `usize` address space does not replace checking the construction's smaller limits. Unique nonces are required across messages under the same initial key; a new context starts a new message, not a continuation.

Availability labels record the audit baseline plus the versioned integration follow-ups above. **Profile/dependency** identifies protocol integration outside the bare cipher layer. Pending items remain requirements even when their underlying modes are already released.

## Primitive and base modes

| Construction | Authoritative definition | Parameters / limits | Baseline and vector evidence |
|---|---|---|---|
| Kuznyechik block permutation | [RFC 7801 §§4.1–4.5](https://www.rfc-editor.org/rfc/rfc7801.html#section-4) | 16-byte block, 32-byte key; no IV, padding, authentication or message mode | **Released** `Cipher`; Kuznyechik key schedule, encryption and decryption examples in [§§5.4–5.6](https://www.rfc-editor.org/rfc/rfc7801.html#section-5.4). Raw encryption of blocks alone is not a complete message protection scheme. |
| ECB | [NIST SP 800-38A §6.1](https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38a.pdf), referenced as MODES by RFC 8645 | Complete 16-byte blocks; no IV or tag; padding external | **Released** `ecbEncrypt/ecbDecrypt`; NIST appendix F **AES** examples validate the generic construction, not published Kuznyechik ECB outputs. |
| CTR | [RFC 8645 §6.2.2](https://www.rfc-editor.org/rfc/rfc8645.html#section-6.2.2), underlying [GOST R 34.13-2015](https://www.rfc-editor.org/rfc/rfc9189.html#section-12.1) / NIST §6.5 | Library profile: c=32..96 in byte steps; nonce=(128-c) bits; initial low counter zero; at most 2^(c-1) blocks under the conservative RFC 8645 profile | **Released** `Ctr`, `CtrWithCounter`; default c=64 / nonce8. RFC 8645 A.2.1 initial keystream is **AES-256**. Generalized library CTR is deliberately bounded like CTR-ACPKM, without rekeying. |
| CBC | NIST §6.2; underlying GOST R 34.13-2015 | Complete blocks; unpredictable IV; library allows a positive whole-block IV register; no implicit padding or tag | **Released** `Cbc`, `CbcWithIv`; [RFC 3602 §4](https://www.rfc-editor.org/rfc/rfc3602.html#section-4) and NIST appendix F are **AES**, with one-block IV. Multi-block GOST feedback needs separate reference coverage. |
| Full-block CFB | NIST §6.3; underlying GOST R 34.13-2015 | Unpredictable IV; library feedback segment=128 bits; partial final segment supported; positive whole-block IV register | **Released** `Cfb`, `CfbWithIv`; NIST appendix F **AES-CFB128** examples. CFB8/CFB1 and general sub-block GOST segment sizes are **not exposed**; do not claim every parameterization. |
| OFB | NIST §6.4; underlying GOST R 34.13-2015 | Unique IV for a key; full-block keystream with partial final block; positive whole-block IV register | **Released** `Ofb`, `OfbWithIv`; NIST appendix F **AES** examples. No OFB-ACPKM variant is specified in RFC 8645 §6. |
| OMAC1 / CMAC | [RFC 4493 §§2.2–2.5](https://www.rfc-editor.org/rfc/rfc4493.html#section-2); Kuznyechik substitution explicitly specified by [RFC 9189 §4.3.2](https://www.rfc-editor.org/rfc/rfc9189.html#section-4.3.2) | No nonce; empty message defined; complete final block and padded final block use distinct subkeys; full tag16; `verify` accepts nonempty byte prefixes up to16 | **Released** `Cmac`; RFC 4493 §4 examples are **AES-128**, not Kuznyechik vectors. Protocol must fix tag length rather than let an attacker choose it. |
| GCM | [NIST SP 800-38D §§5–7](https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38d.pdf); generalized dimensions [RFC 8645 §6.2.3](https://www.rfc-editor.org/rfc/rfc8645.html#section-6.2.3) | Library c=32..64 in byte steps; nonce=(128-c) bits; initial mask counter1, payload starts2; payload ≤16(2^(c-1)-2) bytes and both encoded bit lengths fit u64; tag4,8,12..16 bytes | **Released** `Gcm`, `GcmWithCounter`. Default nonce12/c32 matches usual direct GCM counter formation; shorter generalized nonces follow the RFC family and are **not** ordinary NIST variable-IV GCM. AES known answers and Zig AES-GCM differential tests are **generic-construction evidence**. Short tags additionally require NIST appendix C usage budgets. |

RFC 7801 defines the primitive, not the GOST R 34.13 message modes. ECB, CBC, CFB, OFB and OMAC availability must not be represented as modes defined by RFC 7801. AES-specific RFCs such as [RFC 3686](https://www.rfc-editor.org/rfc/rfc3686.html), [RFC 4106](https://www.rfc-editor.org/rfc/rfc4106.html), [RFC 4309](https://www.rfc-editor.org/rfc/rfc4309.html) and [RFC 5297](https://www.rfc-editor.org/rfc/rfc5297.html) do not by themselves assign Kuznyechik CTR/GCM/CCM/SIV profiles. Their AES nonce layouts must not silently replace the applicable GOST layouts.

## Generic RFC modes that must not disappear from scope

A search restricted to RFCs naming Kuznyechik misses generic constructions. The literal request for **all RFC constructions applicable to this 128-bit cipher** also reaches the following two modes. Neither was implemented/exported at the v0.4.1 baseline. Both are now included in the proposal, and CCM ships in v0.5.0 and OCB in v0.8.0. Neither has a Kuznyechik-specific registered RFC parameter set. They are applicable generic modes, rather than AES-only registered profiles.

| Generic mode | Exact constraints / sections | Vector evidence and availability |
|---|---|---|
| CCM | [RFC 3610 §§1,2.1–2.6](https://www.rfc-editor.org/rfc/rfc3610.html#section-2): any 128-bit block cipher; key32 for Kuznyechik; L=2..8 bytes; unique nonce length15-L (7..13 bytes); payload length `<2^(8L)` bytes; AAD length `<2^64` bytes; tag M=4,6,8,10,12,14,16 bytes, protocol fixed; counter0 masks MAC, payload starts1. Combined CBC-MAC/CTR encryption calls under a key must not exceed2^61. | **Released v0.5.0**, `Ccm` / `CcmWithLength(L)`. All 24 RFC AES packet vectors and 49 independent Node/OpenSSL cases pass. [§8](https://www.rfc-editor.org/rfc/rfc3610.html#section-8) vectors are **AES**. Encryption needs total payload length before CBC-MAC formatting; verify privately before releasing plaintext. |
| OCB (RFC version, often OCB3) | [RFC 7253 §§3,4.1–4.3,5–5.1](https://www.rfc-editor.org/rfc/rfc7253.html#section-3): generic 128-bit block cipher and inverse; key32; unique nonce at most120 bits; fixed tag at most128 bits. Named AES byte profiles use nonce1..15 bytes, tags8/12/16. Empty plaintext/AAD allowed; partial final block has separate rules. §5 recommends ≤2^48 blocks including AAD per key, far below the2^64 security-degradation scale. | **Released v0.8.0**, `Ocb` / `OcbWithTag(bytes)`. [Appendix A](https://www.rfc-editor.org/rfc/rfc7253.html#appendix-A) vectors are **AES**. Requires decryption primitive and authentication before plaintext release; no Kuznyechik AEAD registry assignment is supplied. |

By contrast, [RFC 5297 §§1,2.2–2.7](https://www.rfc-editor.org/rfc/rfc5297.html#section-1) specifies **SIV-AES**, and [RFC 8452 §3](https://www.rfc-editor.org/rfc/rfc8452.html#section-3) specifies **AES-GCM-SIV**. Replacing AES is a new instantiation, not one of their registered algorithms. SIV/S2V is a plausible optional extension with two independent Kuznyechik keys (64 bytes total), but no published Kuznyechik profile/vector was found; do not claim RFC SIV-AES interoperability. [RFC 10032 §§3–5](https://www.rfc-editor.org/rfc/rfc10032.html#section-3) AEGIS depends on the **AES round function**, so replacing it with the Kuznyechik block permutation is not an applicable mode instantiation. Likewise, RC5/DES/Camellia-specific modes and AES key-wrap profiles do not become Kuznyechik standards through renaming.

## All seven RFC 8645 internal modes

Common rules: [§6.2.1](https://www.rfc-editor.org/rfc/rfc8645.html#section-6.2.1) requires block-divisible `N`; [§6.3.1](https://www.rfc-editor.org/rfc/rfc8645.html#section-6.3.1) additionally requires `T*` divisible by `n` and derivation width `d`. Reject zero sizes. ACPKM derives the next key using encrypted bytes 0x80..0x9f. Master material comes from CTR-ACPKM with a 64-bit all-ones nonce; `d*l ≤128*2^63`. Counters/feedback continue across sections.

In this table lengths and formulas are **bits**. Let `L_d = 128*2^63/d`, interpreted with the exact integer material budget and `l=ceil(message_bits/N)`.

| Mode / exact section | Nonce, IV, authentication | Message maximum / material | Availability |
|---|---|---|---|
| [CTR-ACPKM §6.2.2](https://www.rfc-editor.org/rfc/rfc8645.html#section-6.2.2) | Unique (128-c)-bit nonce; c=32..96, byte steps | `128*2^(c-1)` | **Released v0.7.0** |
| [GCM-ACPKM §6.2.3](https://www.rfc-editor.org/rfc/rfc8645.html#section-6.2.3) | Unique nonce; c=32..64; fixed tag policy; hash/mask keep initial key | `min(128*(2^(c-1)-2),2^64-1)` | **Released v0.7.0** |
| [CTR-ACPKM-Master §6.3.2](https://www.rfc-editor.org/rfc/rfc8645.html#section-6.3.2) | Unique nonce; c=32..96 | `min(N*L_256,128*2^c)`; d=256 | **Released v0.7.0** |
| [GCM-ACPKM-Master §6.3.3](https://www.rfc-editor.org/rfc/rfc8645.html#section-6.3.3) | Unique nonce; c=32..64; hash/mask use first **derived** key | `min(N*L_256,128*(2^c-2),2^64-1)`; d=256 | **Released v0.7.0** |
| [CBC-ACPKM-Master §6.3.4](https://www.rfc-editor.org/rfc/rfc8645.html#section-6.3.4) | Unpredictable IV16; complete nonempty blocks; external padding | `N*L_256`; d=256 | **Released v0.7.0** |
| [CFB-ACPKM-Master §6.3.5](https://www.rfc-editor.org/rfc/rfc8645.html#section-6.3.5) | Unpredictable IV16; full-block feedback, final partial allowed | `N*L_256`; d=256 | **Released v0.7.0** |
| [OMAC-ACPKM-Master §6.3.6](https://www.rfc-editor.org/rfc/rfc8645.html#section-6.3.6) | No nonce; final subkey comes from section material | `N*L_384`; d=384 (key256 + subkey128) | **Released v0.7.0** |

[Appendix A.2.1](https://www.rfc-editor.org/rfc/rfc8645.html#appendix-A.2.1) covers the two non-master modes; [A.2.2](https://www.rfc-editor.org/rfc/rfc8645.html#appendix-A.2.2) covers all five master modes. These are **AES-256** examples, including intermediate material. Test generic factories with AES adapters, then separately validate their Kuznyechik instantiations. The formal empty-message OMAC-Master pseudocode has `l=ceil(0/N)=0` yet uses the last section key; an implementation must explicitly document and independently validate its empty-message extension.

ACPKM and ACPKM-Master are internal mode components, not two additional message modes. A plain CTR context's half-counter limit cannot be reused unchanged for master CTR/GCM, whose payload counter budgets use `2^c`. GCM's authentication key does not follow payload rekeying. Resetting CBC/CFB feedback or counters at a section boundary changes the construction.

## MGM and protocol compositions

| Construction / authoritative sections | Kuznyechik constraints | Baseline / authoritative examples |
|---|---|---|
| MGM AEAD and authentication-only use: [RFC 9058 §§4,4.1,4.2](https://www.rfc-editor.org/rfc/rfc9058.html#section-4) | Unique 127-bit ICN represented by 16 bytes with top bit clear; tag S=32..128 bits fixed by protocol; `0 < aad_bits+payload_bits <2^64`; empty one side allowed, both empty forbidden. Encryption increments right64; authentication increments left64 modulo2^64. | **Released v0.6.0** `Mgm`. [A.1.1](https://www.rfc-editor.org/rfc/rfc9058.html#appendix-A.1.1) and [A.1.2](https://www.rfc-editor.org/rfc/rfc9058.html#appendix-A.1.2) are genuine **Kuznyechik** MGM vectors, including an AAD-only case. A.2 is **Magma**, not Kuznyechik. Byte tag APIs cover S divisible by8 only. |
| CTR-OMAC record composition: [RFC 9189 §§4.1.1,4.3.2,4.3.3](https://www.rfc-editor.org/rfc/rfc9189.html#section-4.1.1) | Separate ENC/MAC keys; OMAC16 over sequence/type/version/length/plaintext; CTR-ACPKM encrypts plaintext **and MAC**, section4096 bytes; IV8=(base IV+seqnum) mod2^64 | **Released v0.8.0** `TlsCtrOmac`, a record cipher composition. [A.1.2.2](https://www.rfc-editor.org/rfc/rfc9189.html#appendix-A.1.2.2) supplies **Kuznyechik** records. TLS framing and TLSTREE are separate protocol dependencies. |
| KExp15 / KImp15: [RFC 9189 §8.2.1](https://www.rfc-editor.org/rfc/rfc9189.html#section-8.2.1) | Independent keys32 each; unique IV8 per key pair; OMAC16 over IV\|\|secret, then ordinary CTR over secret\|\|MAC; import input≥16 bytes; total secret+MAC length obeys underlying CTR counter budget | **Released v0.8.0** `KExp15` (seal/export and open/import). [A.1.3.2](https://www.rfc-editor.org/rfc/rfc9189.html#appendix-A.1.3.2) includes Kuznyechik handshake intermediates and PS export. It is key wrapping, **not CTR-ACPKM**. Reject malformed/tag failures without releasing secret. |
| Password-based CTR-ACPKM-OMAC: [RFC 9337 §§5.1.1–5.1.2,7.3](https://www.rfc-editor.org/rfc/rfc9337.html#section-5.1.1) | UKM16: nonce8 plus KDF seed8; DK32; derive ENC/MAC keys with KDF_TREE label `kdf tree`, R=1; OMAC16 over plaintext, then CTR-ACPKM over plaintext\|\|MAC; section size fixed by protocol; combined length inherits CTR-ACPKM budget | **Released v0.8.0** `CtrAcpkmOmac` cipher layer. Distinct from TLS CTR-OMAC and KExp15: no TLS header, no IV in MAC input. PBKDF2/HMAC-Streebog and parameter serialization are dependencies: salt8..32 bytes, iteration count≥1000, unique salt and UKM (§8). Appendix A contains **PBKDF2 only**, not cipher-mode vectors. |
| TLS1.3 MGM adapter: [RFC 9367 §§4.1,4.1.1](https://www.rfc-editor.org/rfc/rfc9367.html#section-4.1) | Nonce16, clear its first-byte top bit before raw MGM; tag16; per-record derived key. `_L` seqnum≤2^64-1, `_S`≤2^42-1 ([§4.1.3](https://www.rfc-editor.org/rfc/rfc9367.html#section-4.1.3)). | **Released v0.9.0** `Tls13MgmL` / `Tls13MgmS` cipher profiles with caller-derived record keys. Same MGM, not a new internal mode. [A.1](https://www.rfc-editor.org/rfc/rfc9367.html#appendix-A.1) is **Kuznyechik MGM_S**, [A.2](https://www.rfc-editor.org/rfc/rfc9367.html#appendix-A.2) **Magma MGM_L**. TLS record length/framing and TLSTREE remain distinct. Raw MGM should reject top-bit-set input; adapter masks it. |
| ESP/IKEv2 MGM-KTREE and ESP-only MGM-MAC-KTREE: [RFC 9227 §§4.1–4.8](https://www.rfc-editor.org/rfc/rfc9227.html#section-4) | Key material44 bytes=root32+salt12; IV8=i1(1)\|\|i2(2)\|\|i3(2)\|\|pnum(3); ICN16=0\|\|pnum\|\|salt; tag12. IV unique per SA; ≤2^24 messages/leaf key; message≤2^16 octets; leaf load≤2^41 octets ([§5](https://www.rfc-editor.org/rfc/rfc9227.html#section-5)). | **Released v0.9.0** `EspMgmKtree`, `EspMgmMacKtree`, `IkeMgmKtree` cipher profiles with caller-derived leaf keys. Full AEAD ID32 and MAC-only ID34 reuse MGM; no new internal mode. MAC-only authenticates plaintext as AAD with empty encrypted payload. [Appendix A](https://www.rfc-editor.org/rfc/rfc9227.html#appendix-A) includes **Kuznyechik** transform examples, separate from Magma. |

These profiles add observable composition behavior even though they reuse existing mathematical modes. Supporting raw MGM alone does not establish RFC 9367 or RFC 9227 interoperability. Conversely, implementing every TLS handshake, certificate, signature or IKE exchange is not part of a cipher-mode library. Keep reusable protection/key-wrap compositions in the scope inventory and mark protocol glue explicitly.

## Other RFCs examined and exclusions

The [IETF Datatracker reference graph](https://datatracker.ietf.org/api/v1/doc/relateddocument/?target__name=rfc7801&limit=100) was checked as well as keyword searches. Its eight published RFC references are 8891, 9058, 9189, 9227, 9312, 9337, 9367 and 9385; RFC 8645 is additionally relevant because it specifies generic constructions. Internet-Drafts (including GOST JOSE work) are not published RFC requirements.

| Source | Classification / consequence |
|---|---|
| [RFC 8645 §§5.2.1,5.3.1](https://www.rfc-editor.org/rfc/rfc8645.html#section-5.2.1) | ExtParallelC and ExtSerialC are generic **block-cipher key derivation**, applicable to Kuznyechik, but not message encryption modes. `acpkm` and `AcpkmMaster` are released in v0.7.0; external RFC KDFs remain a separate scope. A.1.1/A.1.2 give **AES-256** vectors. |
| [RFC 8645 §§5.2.2,5.2.3,5.3.2,7](https://www.rfc-editor.org/rfc/rfc8645.html#section-5) | HKDF/tree schedules and composition with external rekeying; not additional internal cipher modes. Key lifetime across multiple messages remains an application obligation. |
| [RFC 9189 §8.1](https://www.rfc-editor.org/rfc/rfc9189.html#section-8.1), [RFC 9367 §4.1.2](https://www.rfc-editor.org/rfc/rfc9367.html#section-4.1.2), [RFC 9227 §4.1](https://www.rfc-editor.org/rfc/rfc9227.html#section-4.1) | TLSTREE/KTREE use **HMAC-Streebog** KDF_GOSTR3411_2012_256. They are protocol key schedules, not Kuznyechik modes; masks/labels and key-lifetime policies differ by profile. Do not substitute ACPKM. |
| [RFC 7836 §§4.1–4.6](https://www.rfc-editor.org/rfc/rfc7836.html#section-4.1) | GOST hash-based PRFs/KDFs and accompanying algorithms; §4.6 key wrapping explicitly uses **GOST28147-89**, not Kuznyechik. No additional Kuznyechik encryption mode. |
| [RFC 4357 §§2–6](https://www.rfc-editor.org/rfc/rfc4357.html#section-2), [RFC 5830](https://www.rfc-editor.org/rfc/rfc5830.html), [RFC 8891](https://www.rfc-editor.org/rfc/rfc8891.html) | GOST28147-89/CryptoPro meshing/wrapping or Magma. CNT/IMIT, KExp28147 and CryptoPro key wrap are **different ciphers**, not missing Kuznyechik modes. |
| [RFC 9337 §§4,6,7](https://www.rfc-editor.org/rfc/rfc9337.html#section-4) | Password derivation, PBMAC1/HMAC and ASN.1 parameters are not cipher modes. Its **CTR-ACPKM-OMAC composition is applicable** and appears above; do not exclude the entire RFC as a KDF specification. |
| [RFC 9385 §4 and Appendix A](https://www.rfc-editor.org/rfc/rfc9385.html#section-4) | IKEv2 signatures/authentication/PRFs; uses the existing RFC 9227 MGM transforms, no additional mode. Appendix A adds complete IKE protection examples. |
| [RFC 9312 §2.1](https://www.rfc-editor.org/rfc/rfc9312.html#section-2.1) | Its reference to RFC 7801 occurs in a QUIC version-greasing discussion, not a cipher definition. It does not define any Kuznyechik mode/profile. |

## Validation and remaining scope

Current APIs reject documented writable overlaps and invalid parameters before
writes. Authenticated opens verify tags before changing ciphertext. Independent
references, RFC examples, alignment and boundary tests are recorded in the
[validation index](validation/README.md) and [review index](reviews/README.md).
Historical audit findings and their versioned resolutions are preserved in the
[research archive](performance/README.md).

Tag policies, nonce/IV requirements and lifetime usage budgets remain documented
caller duties. The library supplies byte-oriented mode APIs; AEAD streaming and
additional bit-level parameterizations are tracked in [issue #7](https://github.com/beldmian/kuznechik.zig/issues/7).
Protocol framing, replay state, hash-based KDFs and complete TLS/IKE exchanges
remain outside the cipher layer. Coverage does not imply a formal security proof
or physical performance optimality.

## Decision on remaining API dimensions (issue #7)

The supported public surface remains byte-oriented for this release. Sub-block
CFB segments and non-byte-aligned tags are deferred until there is a concrete
interoperability requirement, an explicit bit-order/length contract and
independent vectors. The current CFB and byte-tag APIs do not claim those
parameterizations. General NIST variable-IV GCM is also outside the raw GCM
API's RFC 8645 nonce/counter family.

Authenticated-encryption streaming contexts are deferred: a future opening
API must either authenticate before writing caller-visible plaintext or specify
a separate private staging mechanism with explicit ownership and failure
semantics. Streaming must not silently weaken the existing open contract.
This decision adds no streaming or bit-level functionality and does not imply
registered Kuznyechik profiles for generic AES-named RFC algorithms. Protocol
key derivation, framing, replay protection and cumulative key-use accounting
remain caller responsibilities.
