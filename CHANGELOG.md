# Changelog

## 0.9.4 — 2026-10-29

- Enable CBC batching for all remaining 53 IV widths in 4–63 after measuring each width, replacing the whitelist with `iv_blocks >= 2`.
- Preserve IV2/IV3 thresholds, existing large-register paths, default one-block-IV behavior, context layouts, and complete state across updates and direction changes.
- Add independent AES/Kuznechik references for every newly enabled width, including all alignments, ring and group boundaries, guarded buffers and atomic length rejection.
- Retain measured throughput gains with explicit small short-call costs; preserve full raw data, unchanged controls, source archives, test receipts and VM cleanup.
- Run the complete integration suite on a larger Boat VM following killed local compile attempts; exact checks are recorded in the v0.9.4 integration receipt.

## 0.9.3 — 2026-10-29

- Extend CBC encryption batching to measured IV widths 2/3/4/8/16/24/31/32/63. Entry thresholds are 128 bytes for IV2, 48 bytes for IV3 and 64 bytes for the others; bound scratch to the register width.
- Preserve existing large-register paths, context layouts and exact state across partial updates and direction changes. Medium CFB candidates were rejected for short-call costs and are not enabled.
- Require AVX2 in the LLVM GFNI feature gate: synthetic AVX2-disabled targets now select the fallback instead of failing vector-register allocation. Normal eligible targets keep their accelerated dispatch.
- Preserve hybrid byte-position rejection evidence without changing its released policy; retain raw paired timings, compiler output and independent correctness checks.
- Record combined validation and target-profile checks in the v0.9.3 integration receipt, with reproducible CBC results and rejected candidates.

## 0.9.2 — 2026-10-29

- Batch CBC encryption with IV registers of at least 64 blocks and CFB encryption with power-of-two IV registers of at least 64 blocks. Short updates keep scalar paths; CFB IV65 batching was rejected after a portable short-call regression.
- Preserve all context layouts and observable register/keystream/feedback state, including direction continuation. CBC rejects invalid lengths before changing data or context.
- Add independent AES/Kuznechik shift-register checks across alignments, ring/batch boundaries, partial CFB updates, and atomic rejection.
- Retain paired native/portable Boat improvements for large eligible IVs, with raw samples, controls, rejected variants, layout contracts, source archives and cleanup evidence.
- Verify the combined feedback and OCB changes against the complete library suite before publication; see the v0.9.2 integration receipt for exact configurations and results.

## 0.9.1 — 2026-10-29

- Bound OCB offset schedule initialization by the full-block counts of AAD and payload, avoiding unused entries for short messages while preserving the inclusive L48 endpoint.
- Preserve public APIs, fixed bounded storage, validation and overlap checks, and authentication before plaintext writes.
- Add 280 independent OpenSSL boundary cases and arithmetic checks through the maximum schedule index; retain all existing RFC and independent fixtures.
- Archive paired native/portable Boat comparisons against v0.9.0, including unchanged controls, reversed module placement, raw timings and small large-call regressions. Benefits are concentrated in short messages and records.
- Verify 101 native tests in ReleaseSafe/ReleaseFast, portable Debug/Safe/Fast, and linked AArch64 compilation; confirm benchmark VM deletion.

## 0.9.0 — 2026-10-29

- Add RFC 9367 TLS 1.3 MGM_L/MGM_S and RFC 9227 ESP/IKEv2 MGM-KTREE and ESP MGM-MAC-KTREE cipher profiles, with checked metadata helpers and caller-derived keys. Protocol state, framing and HMAC-Streebog key derivation remain external.
- Add bounded multipart MGM AAD processing; capture nonce values before encryption can overwrite their source storage. The independent review's nonce-alias defect was fixed before publication.
- Verify all 17 published Kuznyechik TLS records and four RFC 9227 examples, with additional independent reference, multipart, alias and rejection checks.
- Reduce GFNI register copies by selecting one-use operands for the first eight output XORs. Preserve the 70-map circuit, Cipher layout, block APIs, feature gates and tail policy.
- Batch OFB bookkeeping for IV registers of at least 64 blocks, with a separate scalar path for short updates. Retain repeated gains on large messages after rejecting the initial short-update regression. CFB and CMAC experiments did not justify changes.
- Archive exact sources, rejected candidates, paired Boat timings and final integration checks: 99 native tests; 91 portable passes with two expected GFNI skips.

## 0.8.1 — 2026-10-29

- Reduce the Zen 5 large-batch linear circuit from 75 to 70 GFNI maps and from 194 to 179 binary XOR nodes using a verified diagonal normalization.
- Retain repeated public-API gains across affected tested widths, including reversed module placement; reject the 69-map candidate because its generated code and API results were worse.
- Preserve Cipher layout, public APIs, tail policy, feature gates, and non-Zen fallbacks, including required assembly memory clobbers.
- Archive algebraic checks, deterministic source generation, assembly, raw paired timings, and native/portable/feature/AArch64 validation.

## 0.8.0 — 2026-10-29

- Add generic RFC 7253 OCB with batched encrypt/decrypt operations, fixed tag types, and private verification before plaintext writes.
- Add RFC 9189 KExp15/KImp15 and TLS CTR-OMAC, plus the cipher layer of RFC 9337 CTR-ACPKM-OMAC, with fixed encrypted 16-byte tags.
- Verify OCB against every Appendix A tuple and aggregate checksum, 394 OpenSSL cases, and guarded Kuznechik boundaries; verify compositions against genuine RFC 9189 examples and 162 complete independent outputs.
- Record independent reviews of OCB/compositions and MGM/ACPKM, including additional reference, alias, polynomial, counter and streaming checks. Neither review found a blocking defect.
- Document protocol framing and external KDF dependencies separately from the exported cipher layer.

## 0.7.1 — 2026-10-29

- Feed complete CCM MAC blocks directly into the cipher, reducing copying and partial-buffer bookkeeping while preserving unaligned input support.
- Retain the measured native opening improvement after multiple seeds and reversed module layout; portable performance and large-message sealing remain approximately tied.
- Record the rejected tail-retuning experiment: its gains did not repeat and some unchanged tails regressed, so the existing policy remains.
- Verify 5,184 alignment/boundary cases, native and portable optimization modes, and AArch64 compilation.

## 0.7.0 — 2026-10-29

- Add all seven RFC 8645 internal modes: CTR/GCM-ACPKM, CTR/GCM/CBC/CFB/OMAC-ACPKM-Master, plus ACPKM and ACPKM-Master derivations.
- Preserve counter, feedback, partial keystream, and MAC state across sections and streaming updates; validate full master counter ranges and material budgets before writes.
- Batch independent work, optimize full-block CFB encryption, and authenticate GCM before plaintext writes.
- Verify all Appendix A.2 vectors, including the specified AES-192 GCM-Master key, and independently check Kuznechik across splits and section boundaries.
- Archive native integration tests and paired serial/batch measurements with full output checks.

## 0.6.0 — 2026-10-29

- Add RFC 9058 MGM with full and detached 4–16-byte tags, unaligned buffers, and verification before plaintext writes.
- Batch independent counters, combine short-message work, and accelerate the authentication product with PCLMUL and deferred reduction; retain a portable implementation.
- Verify both official Kuznechik examples and 1,688 independent AES/Kuznechik reference cases, including remainders, counter wrap, rejection preservation, and buffer overlaps.
- Archive native Boat timing samples, compiler/configuration details, reference generators, and reproduction commands.

## 0.5.0 — 2026-10-29

- Add allocation-free RFC 3610 CCM with all length-field and byte-tag dimensions, batched counters, and authentication before plaintext writes.
- Validate message and per-call cipher budgets; reject buffer overlap before writes.
- Verify all 24 RFC packet vectors, 49 independent Node/OpenSSL fixtures, Kuznechik alignment/tail boundaries, and unchanged ciphertext on rejection.
- Record native Boat comparisons of serial and batched counter processing for both sealing and opening.

## 0.4.2 — 2026-10-29

- Reject overlapping GCM AAD/payload and detached output-tag buffers before writes, fixing authentication of accidentally overwritten AAD.
- Preserve buffers on overlap errors and test adjacent packet slices, exact aliases, and partial overlaps.
- Document the expanded RFC coverage inventory and remaining CCM, OCB, and composition requirements.

## 0.4.1 — 2026-10-29

- Use a 75-map diagonally encoded Toeplitz circuit for Zen 5 batches, replacing the serial recurrence and intermediate compensated-key path.
- Preserve the original recurrence fallback for other CPU profiles and the existing Cipher layout.
- Record paired comparisons against v0.4.0, complete output checks, component proofs, and native mode integration tests.
- Process aligned ECB buffers directly through the batch API; retain staging for unaligned buffers and test all 16 byte alignments with guards.

## 0.4.0 — 2026-10-29

- Add allocation-free byte APIs for ECB, CTR, CBC, full-block CFB, OFB, and CMAC/OMAC.
- Preserve partial keystream across streaming updates; support multi-block feedback IVs.
- Batch independent counter encryption, CBC decryption, and CFB decryption.
- Add GCM with RFC 8645 counter dimensions and message bounds, accelerated standard-library GHASH, detached tags, and verification before decryption.
- Verify generic mode constructions against RFC 3602, RFC 4493, RFC 8645, NIST SP 800-38A, and standard-library AES-GCM; exercise Kuznechik streaming and batch boundaries.
- MGM and ACPKM constructions remain work in progress for subsequent releases.

## 0.3.0 — 2026-10-29

- Add in-place independent-block batch encryption and decryption.
- Add measured Zen 5, Broadwell, portable interleaved, and feature-gated GFNI kernels.
- Accelerate key expansion while preserving the existing `Cipher` layout and keys.
- Add compensated feedback keys for long Zen 5 batches.
- Add differential, exhaustive component, alignment, and batch-boundary checks.
- Add reproducible benchmarks, raw Boat measurements, and performance reports.
- Fix library module export and explicit optimization build options.

Further linear-circuit experiments and RFC cipher modes are developed in later increments.
