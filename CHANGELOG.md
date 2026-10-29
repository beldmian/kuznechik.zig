# Changelog

## 0.3.0 — 2026-10-29

- Add in-place independent-block batch encryption and decryption.
- Add measured Zen 5, Broadwell, portable interleaved, and feature-gated GFNI kernels.
- Accelerate key expansion while preserving the existing `Cipher` layout and keys.
- Add compensated feedback keys for long Zen 5 batches.
- Add differential, exhaustive component, alignment, and batch-boundary checks.
- Add reproducible benchmarks, raw Boat measurements, and performance reports.
- Fix library module export and explicit optimization build options.

Further linear-circuit experiments and RFC cipher modes are developed in later increments.
