# Fuzzing status

The repository has raw-cipher harness callbacks for block round trips, key
expansion and LS transformations. Their standalone entrypoints currently run
fixed smoke vectors. The AFL helper scripts do not yet deliver mutated stdin
or file input to those callbacks; some runner/build target names also disagree.
These are tracked in [issue #3](https://github.com/beldmian/kuznechik.zig/issues/3).

The key-schedule harness's uniqueness/nonzero assertions are not valid for all
master keys. Zero keys and equal key halves are legitimate inputs; replacing
that oracle is tracked in [issue #4](https://github.com/beldmian/kuznechik.zig/issues/4).
Do not interpret those assertions as cipher requirements or their failures as
cipher defects.

## Existing build targets

```sh
zig build fuzz-build
zig build fuzz-test
```

`fuzz-test` runs deterministic smoke checks. It does not establish mutation,
coverage or sustained-campaign results. The ordinary library suite remains:

```sh
zig build test -Doptimize=ReleaseSafe
```

| Harness | Build step | Executable | Input callback |
|---|---|---|---|
| Block round trip | `fuzz-round-trip` | `zig-out/bin/roundtrip` | 32-byte key followed by a 16-byte block |
| Key schedule | `fuzz-key-schedule` | `zig-out/bin/key_schedule` | 32-byte key |
| LS round trip | `fuzz-ls-roundtrip` | `zig-out/bin/ls_roundtrip` | 16-byte block |

The seed directories are under `test/fuzz/corpus`. `LLVMFuzzerTestOneInput` is
exported, but a compatible fuzzer runtime or explicit standalone input adapter
must invoke it with actual mutations. That integration is unfinished.

## Follow-up validation

After fixing input delivery and oracles, demonstrate distinct supplied inputs
reaching the callback, record actual campaign commands and outcomes, and retain
reproducers for real failures. Add mode-level targets for counter/section
boundaries, streaming splits, aliases and authentication-failure preservation
when extending coverage. Compiler instrumentation and runtime support must be
verified for the pinned Zig toolchain rather than inferred from a successful
build or a fixed-vector smoke check.
