# Changelog

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
