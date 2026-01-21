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

## Current State

The project currently has:
- Unit tests in `src/kuznechik.zig` (lines 127-172)
- Known test vectors from RFC 7801
- No fuzzing infrastructure

## Background Research

Zig 0.15.1 has built-in fuzzing support via `std.testing.fuzz`, but it is currently **unstable** with active bugs (GitHub issues #25470, #24222). The Ziggit community confirms this is a "proof of concept implementation" that won't be prioritized for the next few releases.

Available options:
1. **Built-in fuzzing** (currently broken in 0.15.1)
2. **AFL++** with `zig-afl-kit` - mature, production-ready
3. **Custom simple fuzzer** - quick to implement

## Proposed Solution

### Phase 1: AFL++ Integration (Immediate)

Use AFL++ with `zig-afl-kit` for stable fuzzing now:

1. Add `zig-afl-kit` as a dependency
2. Create fuzz harnesses for:
   - Round-trip encryption/decryption
   - Key scheduling
   - Individual transformations (LS, LS-inv)
3. Add `zig build fuzz` step
4. Create initial corpus from RFC 7801 test vectors

### Phase 2: Native Zig Fuzzing (Future)

When Zig's built-in fuzzing stabilizes, add native harnesses using the same test functions.

## Capabilities

This change introduces one new capability:

### Fuzzing Infrastructure

**Requirements:** See `specs/fuzzing/spec.md`

## Design Considerations

See `design.md` for architectural details on:
- Harness structure and corpus management
- Integration with build system
- Property-based testing approach

## Alternatives Considered

1. **Wait for Zig native fuzzing** - Not viable due to timeline uncertainty
2. **Only use AFL++** - Chosen as Phase 1 approach
3. **Implement custom fuzzer** - Unnecessary complexity given AFL++ maturity

## Impact

- **Build system**: New `fuzz` step, optional dependency on AFL++
- **Testing**: New test files in `test/fuzz/`
- **CI**: Optional fuzzing in continuous integration
- **Dependencies**: Development-only dependency on AFL++/zig-afl-kit

## References

- [RFC 7801 - GOST R 34.12-2015](https://www.rfc-editor.org/rfc/rfc7801.html)
- [zig-afl-kit](https://github.com/kristoff-it/zig-afl-kit)
- [Zig Issue #20702 - Integrated fuzz testing](https://github.com/ziglang/zig/issues/20702)
- [Zig Issue #25470 - Fuzzing broken in 0.15.1](https://github.com/ziglang/zig/issues/25470)
- [0.15.1 Fuzzing Discussion on Ziggit](https://ziggit.dev/t/0-15-1-fuzzing/11696)
- [Fuzzing Zig Code Using AFL++](https://www.ryanliptak.com/blog/fuzzing-zig-code/)
