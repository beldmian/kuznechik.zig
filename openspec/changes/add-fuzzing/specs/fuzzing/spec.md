# Spec: Fuzzing Infrastructure

**Capability:** fuzzing
**Change ID:** add-fuzzing

## ADDED Requirements

### Requirement: Fuzz Harness Functions

The project MUST provide fuzzable harness functions that test cipher properties.

#### Scenario: Round-trip encryption/decryption

**Given** a 48-byte input containing a 32-byte key and 16-byte plaintext
**When** the roundTrip harness is called with this input
**Then** decryption of encryption MUST equal the original plaintext

#### Scenario: Key schedule validation

**Given** a 32-byte key
**When** the keySchedule harness is called
**Then** all generated round keys MUST be unique
**And** all round keys MUST NOT be all zeros

#### Scenario: Transformation round-trip

**Given** a 16-byte block
**When** the lsRoundTrip harness is called
**Then** the inverse LS transformation of LS MUST equal the original block

### Requirement: Corpus Management

The project MUST maintain a corpus of seed inputs for each fuzz harness.

#### Scenario: Initial corpus from test vectors

**Given** the RFC 7801 test vectors exist in the codebase
**When** the corpus is initialized
**Then** each harness MUST have at least one seed file derived from test vectors

#### Scenario: Corpus directory structure

**Given** the test/fuzz directory exists
**When** corpus directories are created
**Then** directories MUST exist at:
  - `test/fuzz/corpus/encrypt_decrypt/`
  - `test/fuzz/corpus/key_schedule/`
  - `test/fuzz/corpus/transformations/`

### Requirement: Build Integration

The project MUST provide build system steps for running fuzzers.

#### Scenario: Build individual fuzzer

**Given** the build.zig file includes fuzz configuration
**When** `zig build fuzz-encrypt-decrypt` is run
**Then** a fuzzer executable MUST be compiled
**And** the executable MUST be runnable with AFL++

#### Scenario: Build all fuzzers

**Given** all fuzz harnesses are implemented
**When** `zig build fuzz` is run
**Then** all fuzzers MUST be compiled or executed
**And** the process MUST exit cleanly

#### Scenario: LLVM backend requirement

**Given** AFL++ requires LLVM instrumentation
**When** fuzz executables are built
**Then** the LLVM backend MUST be used
**And** `use_llvm = true` MUST be set

### Requirement: Fuzzing Documentation

The project MUST document how to use the fuzzing infrastructure.

#### Scenario: Installation instructions

**Given** the README.md file
**When** a developer reads the Fuzzing section
**Then** instructions for installing AFL++ MUST be provided
**And** instructions for running fuzzers MUST be provided

#### Scenario: Usage examples

**Given** a developer wants to run fuzzing
**When** they follow the README instructions
**Then** they SHOULD be able to run `zig build fuzz` successfully
**And** they SHOULD understand how to interpret results

### Requirement: Crash Reporting

The fuzzing setup MUST properly report and preserve crashes.

#### Scenario: Crash file preservation

**Given** AFL++ is running
**When** a crash is discovered
**Then** the crash input MUST be saved to `crashes/` directory
**And** the file SHOULD be reproducible

#### Scenario: Timeout detection

**Given** a harness may hang on certain inputs
**When** AFL++ is configured with a timeout
**Then** inputs exceeding the timeout MUST be saved to `hangs/` directory

## MODIFIED Requirements

### Requirement: Build System

The build system SHALL be extended to support fuzzing steps while maintaining existing functionality.

#### Scenario: Existing build steps unchanged

**Given** the existing build.zig configuration
**When** `zig build test` is run
**Then** existing unit tests MUST still pass
**And** fuzzing steps MUST NOT interfere with normal builds

## REMOVED Requirements

None. This is a pure addition with no breaking changes.

## Cross-References

- Related to: testing (existing unit tests in src/kuznechik.zig)
- Builds on: RFC 7801 test vectors
- Enables: future native Zig fuzzer integration
