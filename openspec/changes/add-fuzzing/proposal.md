# Proposal: Add Fuzzing for Cipher Implementation

**Change ID:** `add-fuzzing`
**Status:** Draft
**Created:** 2025-01-22

## Summary

Add fuzzing infrastructure to test the Kuznechik cipher implementation for edge cases, security vulnerabilities, and correctness issues. This proposal addresses the item listed in the README's future plans.

## Motivation

Cryptographic implementations require thorough testing to ensure:
- **Correctness**: All input combinations produce valid outputs
- **Security**: No edge cases lead to leaks, crashes, or undefined behavior
- **Robustness**: The cipher handles malformed or unexpected inputs gracefully

Fuzzing is particularly valuable for cryptographic code because:
1. It can find edge cases in the lookup table transformations
2. It validates round-trip properties (encrypt/decrypt)
3. It tests alignment and memory safety issues with the SIMD-like vector operations
4. It can discover timing side-channel vulnerabilities (with appropriate instrumentation)

## Current state — 2026-10-29

Smoke harnesses, corpus inputs and build steps exist, but the executable entry
points do not consume AFL mutation input. The key-schedule harness also contains
invalid assertions for legitimate zero and equal-half keys. This remains a draft;
no sustained fuzzing coverage is claimed.

See [FUZZING.md](../../../docs/FUZZING.md) for current commands and status.
Input delivery and naming are tracked in [issue #3](https://github.com/beldmian/kuznechik.zig/issues/3);
valid key-schedule oracles are tracked in [issue #4](https://github.com/beldmian/kuznechik.zig/issues/4).

## Repair follow-up — 2026-10-31

The user-requested bug fixes for issues #3/#4 now connect stdin/file input,
repair runner naming, and replace false assertions with an independent scalar
schedule oracle and zero/equal-half regressions. A brief real dumb-mode campaign
is recorded in [FUZZING.md](../../../docs/FUZZING.md). This supersedes the
2026-10-29 harness status above. The broader draft (instrumented campaigns,
mode-level coverage, and other optional tasks) is not declared complete.

## Proposed change

Connect actual mutation inputs to deterministic cipher-property checks, use
valid independent oracles, align runner and build names, preserve reproducing
inputs, and document verified fuzzing commands. The remaining draft tasks and
specification describe future work; implementation choices must be reviewed
against the actual repository and toolchain before resuming.

## Impact

Development-only harness, runner, corpus, build and documentation work. The
library cipher API remains unchanged. Native or AFL-based integration and CI
are future implementation decisions. Ordinary unit tests and fixed-vector
smoke runs remain separate from fuzz campaigns.
