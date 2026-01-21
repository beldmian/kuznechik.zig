# Design: Fuzzing Infrastructure for Kuznechik

**Change ID:** `add-fuzzing`

## Overview

This document describes the design of the fuzzing infrastructure for the Kuznechik cipher implementation. The design uses a phased approach to address the current instability of Zig's built-in fuzzing in version 0.15.1.

## Architecture

```
test/
├── fuzz/
│   ├── harnesses.zig      # Fuzz harness functions
│   ├── corpus/            # Seed inputs
│   │   ├── encrypt_decrypt/
│   │   ├── key_schedule/
│   │   └── transformations/
│   └── README.md
build.zig                   # Updated with fuzz step
```

### Component Structure

1. **Harness Module** (`test/fuzz/harnesses.zig`)
   - Export functions with signature `fn ([]const u8) anyerror!void`
   - Each harness tests a specific property or component
   - Compatible with both AFL++ and future native Zig fuzzer

2. **Corpus Management**
   - Directory per harness for organized seed inputs
   - Initial seeds from RFC 7801 test vectors
   - AFL++ will automatically grow and minimize corpus

3. **Build Integration**
   - `zig build fuzz` runs AFL++ on all harnesses
   - `zig build fuzz-harness=<name>` runs specific harness
   - Uses LLVM backend (required for AFL++ instrumentation)

## Harness Design

### Property-Based Testing Approach

Each harness tests an invariant property of the cipher:

#### 1. Round-Trip Harness (`encrypt_decrypt`)

Tests that `decrypt(encrypt(plaintext)) == plaintext`

```zig
pub fn roundTrip(input: []const u8) anyerror!void {
    // Extract key and plaintext from input
    // Verify: decrypt(encrypt(plaintext)) == plaintext
}
```

**Input format:** `[32-byte key][16-byte plaintext]` (48 bytes total)

#### 2. Key Schedule Harness (`key_schedule`)

Tests properties of the round key generation:

```zig
pub fn keySchedule(input: []const u8) anyerror!void {
    // Verify all round keys are unique
    // Verify round keys are non-zero
}
```

**Input format:** `[32-byte key]`

#### 3. Transformation Harness (`transformations`)

Tests individual LS and LS-inverse transformations:

```zig
pub fn lsRoundTrip(input: []const u8) anyerror!void {
    // Verify: ls_inv(ls(x)) == x
}
```

**Input format:** `[16-byte block]`

## Build System Integration

### build.zig Changes

```zig
// Add fuzz step
const fuzz_step = b.step("fuzz", "Run fuzzing with AFL++");

// Create fuzz executable for each harness
const fuzz_exe = b.addExecutable(.{
    .name = "fuzz_encrypt_decrypt",
    .root_source_file = b.path("test/fuzz/harnesses.zig"),
    .target = target,
    .optimize = .Debug,  // Better coverage
});

// Use LLVM backend for AFL++ compatibility
fuzz_exe.use_llvm = true;

// Add AFL++ instrumentation flags
fuzz_exe.root_module.addImport("afl", afl_module);

// Run command
const run_fuzz = b.addRunArtifact(fuzz_exe);
run_fuzz.has_unknown_args = true;  // Pass AFL args
fuzz_step.dependOn(&run_fuzz.step);
```

## Tooling Strategy

### Phase 1: AFL++ (Immediate)

**Advantages:**
- Stable, mature fuzzer
- Good coverage guidance
- Corpus management
- Crash reproduction

**Requirements:**
- AFL++ installed (`apt install afl++` or built from source)
- `zig-afl-kit` for convenience functions

**Workflow:**
```bash
# Initial run with corpus
zig build fuzz

# Continue with previous corpus
zig build fuzz -- corups/

# Specific harness
zig build fuzz -- -h encrypt_decrypt
```

### Phase 2: Native Zig Fuzzer (Future)

When Zig's `std.testing.fuzz` stabilizes:

```zig
test "fuzz encrypt/decrypt round-trip" {
    const harness = struct {
        fn f(input: []const u8) anyerror!void {
            try harnesses.roundTrip(input);
        }
    }.f;

    try std.testing.fuzz(.{}, harness, .{
        .corpus_dir = "test/fuzz/corpus/encrypt_decrypt",
    });
}
```

Migration path:
- Harness functions remain unchanged
- Add thin test wrappers for native fuzzer
- Keep AFL++ for comparison

## Corpus Strategy

### Initial Corpus

Seed from RFC 7801 test vectors:

| Test | Key (bytes 0-31) | Plaintext (bytes 32-47) |
|------|------------------|-------------------------|
| Vector 1 | `88 99 aa bb ...` | `11 22 33 44 ...` |
| Vector 2 | `...` | `...` |

### Corpus Growth

- AFL++ automatically:
  - Discards redundant inputs
  - Minimizes corpus
  - Tracks coverage

- Manual additions for:
  - Boundary cases (all zeros, all ones)
  - Known weak keys (if any discovered)
  - Alignment edge cases

## CI Integration

### GitHub Actions (Optional)

```yaml
- name: Run fuzzing (short run)
  run: zig build fuzz -- -t 60  # 1 minute per harness
  continue-on-error: true  # Don't fail on new crashes
```

### Local Development

```bash
# Quick smoke test
zig build fuzz -- -t 10

# Overnight fuzzing
zig build fuzz -- -t 28800
```

## Error Handling

### Crash Categories

1. **Safety violations** - Panics, out of bounds, overflow
2. **Assertion failures** - Property violations
3. **Timeouts** - Potential infinite loops (AFL++ default: 1.25s)

### Reporting

- AFL++ creates crash files in `crashes/`
- Hang files in `hangs/`
- Best coverage in `queue/`

## Security Considerations

Fuzzing cryptographic code requires care:

1. **Constant-time verification** - Don't add timing-dependent asserts
2. **Secret handling** - Don't hardcode real keys in corpus
3. **Side channels** - Use `valgrind` or specialized tools for timing analysis

## Dependencies

### Development Dependencies

```
afl++      >= 4.00   # System package
zig-afl-kit           # Zig package manager
```

### Optional

```
aflplusplus-tools     # For corpus minimization, plotting
```

## Success Criteria

- [ ] All harnesses run without crashes on initial corpus
- [ ] At least 90% branch coverage in cipher functions
- [ ] No crashes found after 24 hours of fuzzing
- [ ] Corpus grows to cover all transformation paths
- [ ] Build step `zig build fuzz` works on all platforms

## Open Questions

1. Should we include timing side-channel fuzzing? (Requires different tooling)
2. What timeout values for different harnesses?
3. Should fuzzing be part of required CI or optional?

## References

- [AFL++ Documentation](https://github.com/AFLplusplus/AFLplusplus)
- [zig-afl-kit](https://github.com/kristoff-it/zig-afl-kit)
- [Fuzzing in Depth](https://github.com/AFLplusplus/AFLplusplus/blob/stable/docs/fuzzing_in_depth.md)
