# Changelog

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
