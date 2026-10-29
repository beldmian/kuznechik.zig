# Independent MGM / ACPKM review — 2026-10-29

**Findings and objections: none identified in the reviewed MGM / ACPKM code.**
No implementation change or release-blocking correction is proposed. This is a bounded implementation review and independent correctness check, not a formal security proof, timing proof, or proof of physical optimality.

## Scope and fixed inputs

Reviewed the algorithms in `src/modes/mgm.zig` and `src/modes/acpkm.zig`, their tests and fixtures, `src/modes/root.zig` exports, relevant classic feedback code, `docs/MODES.md`, `docs/RFC-MODES.md`, and both performance evidence directories and their provenance notes. Read `AGENTS.md`, `openspec/AGENTS.md`, and `openspec/changes/add-rfc-cipher-modes`.

Review began at `81032ffd800394d9fec124b64010ab9796c65616` (v0.7.0). Review conclusions attach to these exact source hashes, verified locally and on Boat K before testing and again at completion:

```text
4e7fe9f2115d8a6517c984e281d8e6209205a9fefedff357cec0c923780f2ee1  src/modes/mgm.zig
28cebbb0080d37539bb9ce01078aef74895f9a7a26b26a9ae1842e6e396ffc1d  src/modes/acpkm.zig
22c29af66dba00a01984755d053cce2ec45e6d7f2c555d575328b79a3acff955  src/modes/root.zig
1910b95fe988b04ab7639d366be45994420f01b2f79b120c32de9993a482497b  final temporary review driver
```

Primary sources were the cached RFC texts, with particular attention to [RFC 9058 §§3–4 and Appendix A.1](https://www.rfc-editor.org/rfc/rfc9058.html#section-4) and [RFC 8645 §§6.2–6.3 and Appendix A.2](https://www.rfc-editor.org/rfc/rfc8645.html#section-6.2). Cached source SHA-256:

```text
2bc87e4c0078a6807a31307292e9b940092e0ef38e9c3c6c35f5f1ea5f1b312f  rfc9058.txt
08bad083c340eaff1072f16b0f5f57cda8a5e832ad8b1cd8efa5467e837feb38  rfc8645.txt
```

The GCM-Master appendix heading says AES-256, but its explicit `k=192`, 24-byte initial key, and material use AES-192. The existing test and provenance document this accurately; this was not reported as a mismatch.

## Semantic audit

- MGM validates the top nonce bit, protocol-selected byte tag dimensions, nonempty combined message, and strict combined bit-length bound before accessing payload/AAD. The encryption and authentication counters increment the right and left halves respectively, modulo 2^64, without carrying into the other half. Separate zero padding, length authentication, final encryption, and most-significant tag truncation match RFC 9058. Short-message opening computes keystream privately and writes payload only after verification.
- ACPKM constants and truncation follow RFC 8645 §6.2.1. Plain CTR reserves the upper half-counter space; master CTR uses the full space. GCM reserves two counters, begins payload at counter 2, and computes H and the tag mask with the original payload key throughout the message; master mode uses the first derived section key for those operations.
- Master derivation uses an all-ones 64-bit nonce with the plain half-range CTR-ACPKM construction. Section-budget validation counts complete materials, including when the final material leaves unused derivation bytes. T* divisibility by the block and material widths is checked. A cached final gamma byte remains available after new-block exhaustion.
- CBC/CFB preserve feedback across section and update boundaries. OMAC retains its possible final block and uses the last section's supplied subkey directly for a full final block, or doubles that supplied subkey for a padded block. It does not derive a CMAC subkey from a fresh zero-block encryption. Repeated snapshot finalization and subsequent updates preserve these semantics.
- Tag verification precedes payload writes. Overlap rejection uses pointer differences and handles empty and adjacent slices. Byte loads/stores and aligned local cipher blocks support unaligned payload/AAD/tag slices. All public ACPKM aliases and counter factories were instantiated and exercised.
- MGM's accelerated product uses three carryless 64×64 products and a single ordinary-basis reduction modulo x^128+x^7+x^2+x+1. The tied input/output SSE register constraint and PCLMUL feature selection were inspected; the PCLMUL-only target was tested without AVX.

Relevant source locations: `mgm.zig:18`, `:38`, `:58`, `:76`, `:216`, `:230`, `:258`; `acpkm.zig:23`, `:58`, `:91`, `:158`, `:243`, `:289`, `:341`, `:400`, `:423`; `root.zig:13`.

## New independent checks

The temporary driver used raw cipher calls for its new reference constructions; it did not call production mode/rekey/GHASH helpers or the checked-in scalar reference functions to compute expectations.

1. New Kuznechik key and independent CTR, master derivation, GCM tag, CBC, CFB, and OMAC constructions. Sections were 80, 112, 272, and 1040 bytes; encryption/master and MAC lifetimes differed from the checked-in differential cases. Eighteen payload lengths from 0 through 2111 bytes included exact section boundaries and nearby partial blocks. Random update partitions, empty updates, mismatched encryption/decryption partitions, and OMAC snapshots after every update matched the independently computed results.
2. MGM public-API product probe checked **all 16,384 pairs of polynomial basis operands**. An independent Boolean coefficient representation and polynomial division produced expected reductions. Another 24 cases each summed seven random full products before comparison, exercising accumulation before reduction.
3. Reversible toy ciphers with 16/24/33/48/64-byte keys checked generic key/material packing and all construction state transitions. Derivation material widths 1/3/17/24/33/65 bytes checked preservation across partial cipher blocks and master rekey boundaries. These synthetic ciphers are packing/state-machine evidence, not claims of additional secure cipher implementations or new AES known answers.
4. Synthetic end states checked the exact master material budget, the final cached CTR byte, deferred OMAC final blocks, stable snapshot finalization, and atomic rejection of the next update. A 48-byte derivation material was accepted at the last complete material and the next rejected while 32 raw derivation bytes remained. Oversized slices were used only for cases whose rejection was established independently by length arithmetic, and were never passed through an accepted path.
5. Public aliases, adjacent packet fields, and offsets 0 through 31 checked unaligned accesses and invalid-tag preservation for both ACPKM GCM variants and long MGM payloads.
6. An additional independent MGM construction using Boolean polynomial multiplication checked **60 complete ciphertext/tag cases**: four fresh keys, random nonces/AAD/payload, authentication-only and encryption-only cases, 1024-byte boundaries, and both sides of the combined short-message threshold, including AAD=496/payload=256 versus payload=257.
7. Independent counter arithmetic checked all nine CTR widths, plain/master limits, all 17 cached-byte positions, zero through two remaining new blocks, and update lengths 0–49. GCM public counter factories checked all five widths, exact payload bounds, and AAD bit-length rejection.

## Executed verification

Compiler: Zig **0.15.1**, local `/tmp/kuz-toolchains/zig-x86_64-linux-0.15.1/zig`, Boat `/tmp/zig-x86_64-linux-0.15.1/zig`. Every run used review-owned isolated local/global caches. Test names and counts were inspected; no obsolete 27-test result was accepted.

- Local Broadwell, root suite, `-O ReleaseSafe -mcpu=native`: **49 executed; 47 passed, 2 GFNI skips**. This is the Broadwell result, not the Zen 5 native count.
- Boat K `bx_sxaayb5h`, Ryzen 9 9950X guest, pinned to core 0, root suite, `-O ReleaseSafe -mcpu=native`: **55/55 passed**. This includes the MGM and ACPKM module tests and official examples.
- Final review driver, local `-O ReleaseSafe -mcpu=native`: **9/9 passed**.
- Final review driver, local `-O Debug -mcpu=x86_64`: **9/9 passed**, including the portable MGM product path.
- Final review driver, local `-O ReleaseFast -mcpu=x86_64+pclmul`: **9/9 passed**, including legacy PCLMUL without AVX.
- Final review driver, Boat K/core 0, `-O ReleaseSafe -mcpu=native`: **9/9 passed**.

The filtered driver counts comprise seven named review tests plus two unnamed imported declaration anchors. They do not represent the complete root suite; the separate 49/55-test runs establish root coverage. Earlier drivers with five named review tests also passed but are superseded by the final driver above.

The earlier passing PCLMUL-only executable was disassembled on Boat K: **15 legacy PCLMUL instructions, zero VEX PCLMUL instructions**. Its binary SHA-256 is `4328263757ee5427e5af8057647e97f339578dc853103d3ac833f760516ea6b7`, and its driver SHA-256 is `8eeab4c49ac0f09221f3a560d32a19d7f81d8344b7507c76ad799f2c88de3d57`. The production MGM source is identical in that run and the final nine-test runs.

One initial portable compiler attempt aborted when `/tmp` was full; it and an immediately unsuccessful retry are not correctness evidence. Review-owned caches were moved to disk-backed storage before the successful portable runs. An assembly-output command missing Zig's required explicit binary-output flag was also discarded; the instruction evidence above comes from disassembling the executable that actually passed.

## Evidence, cleanup, and limits

Local evidence directory:
`/home/t3/.cache/kuz-reviews/mgm-acpkm-20261029-0829/`

It contains `review-driver.zig`, `source-final.tar.gz`, `source-final-sha256.json`, `final-local-native-safe.log`, `final-local-baseline-debug.log`, `final-local-legacy-fast.log`, `boat-root-native-safe.log`, `final-boat-review-native-safe.log`, and `legacy-instructions.json`. The initial local root output was inspected directly in the review transcript. Earlier driver/log/cache versions are named separately.

Boat evidence is confined to `/home/user/review-mgm-acpkm-20261029-0829/`. Existing `/home/user/kuz-mgm-integration` evidence was preserved. Boat K remains running for root cleanup. No other VM was changed, and no credentials were printed.

The temporary driver was removed from the shared repository's `src/` after archiving; its Boat copy was moved out of `src/` into the review evidence directory. Only this new report was added to repository documentation by this reviewer. No implementation, permanent test, export, or existing documentation file was edited; no commit, push, tag, or release was performed. Concurrent release bookkeeping changes by another agent were left untouched.

Limits: finite deterministic tests and source inspection, raw block cipher shared with the independent oracles, synthetic large states rather than processing impractically large messages, no sustained fuzzing, no new performance measurements, and no hardware outside Broadwell/Zen 5 execution in this review. Caller-managed nonce uniqueness, protocol-fixed tag length, and multi-message lifetime policy remain as documented API obligations. There is no objection to the reviewed MGM/ACPKM implementation on the evidence above; this report makes no finding about the separate unintegrated OCB/composition modules.
