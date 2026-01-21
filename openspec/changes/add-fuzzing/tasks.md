# Tasks: Add Fuzzing for Cipher Implementation

**Change ID:** `add-fuzzing`

## Implementation Tasks

These tasks are ordered to deliver visible progress incrementally. Each task should produce a verifiable result.

### Prerequisites

- [ ] **PREREQ-1**: Verify AFL++ is available or install instructions are documented
  - Check: `afl-fuzz --version` succeeds or `README.md` has install instructions
  - **Dependencies:** None

### Phase 1: Infrastructure Setup

- [ ] **TASK-1**: Create test/fuzz directory structure
  - Create `test/fuzz/` directory
  - Create subdirectories: `corpus/encrypt_decrypt/`, `corpus/key_schedule/`, `corpus/transformations/`
  - **Validation:** `ls test/fuzz/corpus/*/` shows empty directories
  - **Dependencies:** PREREQ-1
  - **Estimated complexity:** Low

- [ ] **TASK-2**: Add zig-afl-kit dependency to build.zig
  - Add as development dependency
  - Create helper module for AFL integration
  - **Validation:** `zig build` fetches zig-afl-kit successfully
  - **Dependencies:** TASK-1
  - **Estimated complexity:** Low

- [ ] **TASK-3**: Create initial corpus from RFC 7801 test vectors
  - Extract test vectors from existing unit tests
  - Create binary seed files for each harness
  - **Validation:** Each corpus directory has at least one seed file
  - **Dependencies:** TASK-1
  - **Estimated complexity:** Low

### Phase 2: Harness Implementation

- [ ] **TASK-4**: Implement round-trip harness (encrypt/decrypt)
  - Create `test/fuzz/harnesses.zig`
  - Implement `roundTrip()` function
  - Parse 48-byte input: [32-byte key][16-byte plaintext]
  - Assert `decrypt(encrypt(plaintext)) == plaintext`
  - **Validation:** Can run function directly with test input
  - **Dependencies:** TASK-3
  - **Estimated complexity:** Medium

- [ ] **TASK-5**: Implement key schedule harness
  - Implement `keySchedule()` function
  - Parse 32-byte input: [key]
  - Assert all round keys are unique and non-zero
  - **Validation:** Unit test passes with known good key
  - **Dependencies:** TASK-4
  - **Estimated complexity:** Medium

- [ ] **TASK-6**: Implement transformation harness
  - Implement `lsRoundTrip()` function
  - Parse 16-byte input: [block]
  - Assert `ls_inv(ls(x)) == x`
  - **Validation:** Unit test passes with random input
  - **Dependencies:** TASK-5
  - **Estimated complexity:** Medium

### Phase 3: Build Integration

- [ ] **TASK-7**: Add fuzz build step for round-trip harness
  - Update `build.zig` with `fuzz-encrypt-decrypt` step
  - Configure AFL++ executable compilation
  - Use LLVM backend
  - **Validation:** `zig build fuzz-encrypt-decrypt` compiles
  - **Dependencies:** TASK-4
  - **Estimated complexity:** Medium

- [ ] **TASK-8**: Add fuzz build steps for remaining harnesses
  - Add `fuzz-key-schedule` step
  - Add `fuzz-transformations` step
  - Add aggregate `fuzz` step
  - **Validation:** `zig build fuzz` runs all three harnesses
  - **Dependencies:** TASK-6, TASK-7
  - **Estimated complexity:** Medium

### Phase 4: Testing and Validation

- [ ] **TASK-9**: Run initial fuzzing campaigns on all harnesses
  - Run each harness for 5 minutes with timeout
  - Verify no crashes on initial corpus
  - **Validation:** All harnesses complete without crashes
  - **Dependencies:** TASK-8
  - **Estimated complexity:** Low

- [ ] **TASK-10**: Document fuzzing workflow in README
  - Add "Fuzzing" section to README.md
  - Document: installation, running, corpus management
  - Include expected outputs and crash handling
  - **Validation:** README has complete fuzzing documentation
  - **Dependencies:** TASK-9
  - **Estimated complexity:** Low

- [ ] **TASK-11**: (Optional) Add CI fuzzing job
  - Create `.github/workflows/fuzz.yml`
  - Configure short fuzz run (5 minutes)
  - Set `continue-on-error: true`
  - **Validation:** CI workflow runs fuzzing step
  - **Dependencies:** TASK-10
  - **Estimated complexity:** Low

### Phase 5: Future Preparation

- [ ] **TASK-12**: Add native Zig fuzzer stub tests
  - Create `test/fuzz/native.zig` with commented-out harnesses
  - Document migration path when Zig fuzzer stabilizes
  - **Validation:** File exists with documentation
  - **Dependencies:** TASK-8
  - **Estimated complexity:** Low

## Parallelizable Work

The following tasks can be done in parallel:
- **TASK-4, TASK-5, TASK-6** (different harnesses, but share same file)
- **TASK-10** (documentation can start in parallel with testing)

## Dependencies Summary

```
PREREQ-1
    |
TASK-1 ──┬──> TASK-2 ───> TASK-7 ───> TASK-8 ───> TASK-9 ───> TASK-10 ───> TASK-11
         │
         └──> TASK-3 ───> TASK-4 ───> TASK-5 ───> TASK-6 ─────────────────────> TASK-12
```

## Definition of Done

A task is complete when:
1. Code compiles without errors
2. Tests pass (if applicable)
3. Validation criteria met
4. Code follows project style

## Notes

- All harnesses should be deterministic (no randomness in assertion logic)
- Use `std.testing.expect` for assertions
- Corpus files should be as small as possible while covering test vectors
- AFL++ runs should use `-t` (timeout) to prevent hangs
