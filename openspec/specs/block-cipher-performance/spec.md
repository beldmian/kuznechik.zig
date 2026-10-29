# block-cipher-performance Specification

## Purpose
Preserve compatible Kuznechik block operations while providing portable and feature-gated batch acceleration, reproducible measurements and claims bounded by recorded evidence.

## Requirements

### Requirement: Cipher compatibility
Optimized encryption and decryption SHALL preserve the existing block API and
match the basic Kuznechik transformations for arbitrary keys and block inputs.

#### Scenario: Differential validation
- **WHEN** randomized blocks and keys are evaluated by the optimized and basic implementations
- **THEN** ciphertexts and plaintexts SHALL match, including decryption of independently generated ciphertexts

### Requirement: Independent block batches
The cipher SHALL expose optional in-place encryption and decryption of slices of
independent raw blocks, preserving the existing 16-byte alignment contract and
single-block methods. Instruction-specific kernels SHALL be selected only when
the compilation target enables all required features.

#### Scenario: Arbitrary batch size
- **WHEN** an empty slice or any batch size, including partial vector tails, is processed
- **THEN** the result SHALL equal processing each block independently and memory outside the slice SHALL remain unchanged

#### Scenario: Portable target
- **WHEN** the compilation target lacks GFNI or required AVX-512 features
- **THEN** the batch API SHALL use portable code without emitting unsupported instructions

### Requirement: Reproducible measurements
The benchmark SHALL measure both directions with runtime data, observable output,
warmup, repeated samples, and separate single-chain and independent-block cases.

#### Scenario: Performance comparison
- **WHEN** baseline and candidate implementations run on a recorded Boat VM CPU with identical compiler settings
- **THEN** results SHALL report per-block latency/throughput, sample counts, and enough configuration to repeat the comparison

### Requirement: Evidence-scoped optimization
Performance claims SHALL be scoped to measured hardware and workloads, and
SHALL NOT claim proof of a universal physical performance limit.

#### Scenario: Final report
- **WHEN** an optimized implementation is delivered
- **THEN** the report SHALL include correctness results, measured gains or regressions, tested hypotheses, and remaining uncertainty
