# cipher-modes Specification

## Purpose
Provide documented byte-oriented Kuznechik cipher modes, authenticated compositions and protocol cipher helpers with RFC-compatible behavior, checked limits and authentication before plaintext writes.

## Requirements

### Requirement: RFC mode behavior
The library SHALL implement documented Kuznechik cipher-mode constructions with the IV, counter, section, authentication, and length rules of their referenced specifications.

#### Scenario: Authoritative known-answer input
- **WHEN** a published test input is processed by the corresponding construction
- **THEN** the ciphertext, tag, and derived keys SHALL match the authoritative expected values.

### Requirement: Streaming and independent block processing
Streaming mode contexts SHALL preserve message semantics across arbitrary update boundaries and SHALL use accelerated batch block operations where dependencies allow it.

#### Scenario: Partitioned stream
- **WHEN** a message is processed in multiple updates
- **THEN** its output SHALL equal the same message processed as a single update.

### Requirement: Authentication and input failures
Authenticated decryption SHALL verify tags before modifying the caller's ciphertext buffer, and input validation SHALL reject invalid parameters and exhausted counters before processing affected data.

#### Scenario: Invalid authentication tag
- **WHEN** ciphertext, associated data, nonce, or tag is altered
- **THEN** decryption SHALL fail without exposing or writing unauthenticated plaintext.

### Requirement: Incremental verified publication
Changes SHALL be published in incremental commits and releases after the relevant correctness checks pass, with performance claims scoped to measured configurations.

#### Scenario: Release checkpoint
- **WHEN** a mode implementation is released
- **THEN** its RFC scope, validation evidence, and material limitations SHALL be documented.

### Requirement: MGM cipher profiles
The library SHALL provide RFC 9367 and RFC 9227 cipher-profile helpers using caller-derived keys, preserving the respective nonce, tag, message-limit and authentication-only rules while documenting external protocol and KDF dependencies.

#### Scenario: Profile-specific cipher operation
- **WHEN** a caller supplies a derived key and valid profile parameters
- **THEN** ciphertext and tags SHALL match the profile's published examples without changing the raw MGM nonce validation rules.
