# Fuzzing status

The standalone harnesses consume stdin, or a file named as their only argument.
`--smoke` runs a separate deterministic vector. Inputs shorter than the required
width are ignored; only the required prefix is used. The runner names are
mapped to the existing build steps and corpus directories.

The key-schedule harness compares every round key against a separate scalar
RFC 7801 expansion, checks inverse linear keys, and reverses each eight-step
Feistel group. The reference has its own S-box and polynomial arithmetic and
uses no production transformation or generated constants. It shares the RFC
algorithm and constants, so agreement is not a proof of correctness or security.
Zero and equal-half master keys are valid regression inputs.

## Existing build targets

```sh
zig build fuzz-build
zig build fuzz-test
```

`fuzz-test` runs deterministic smoke checks and reference/input-adapter unit tests.
It does not establish mutation,
coverage or sustained-campaign results. The ordinary library suite remains:

```sh
zig build test -Doptimize=ReleaseSafe
```

| Harness | Build step | Executable | Input callback |
|---|---|---|---|
| Block round trip | `fuzz-round-trip` | `zig-out/bin/roundtrip` | 32-byte key followed by a 16-byte block |
| Key schedule | `fuzz-key-schedule` | `zig-out/bin/key_schedule` | 32-byte key |
| LS round trip | `fuzz-ls-roundtrip` | `zig-out/bin/ls_roundtrip` | 16-byte block |

The seed directories are under `test/fuzz/corpus`. AFL dumb and QEMU runners
feed stdin to the callback; a filename can also be supplied directly for replay.
A short uninstrumented campaign is recorded below; it does not measure coverage.

## Short campaign (2026-10-30)

On Linux x86-64 (Intel Xeon E5-2690 v4), Zig 0.15.2 Debug, AFL++ 4.21c
`-n -V 10` ran the key-schedule binary with the three checked-in seeds via
stdin. It executed 1,182 cases, saved no crashes or timeouts, and had no
instrumentation or coverage feedback. The final statistics sample is retained
in [the receipt](validation/fuzz-2026-10-30.txt). This is a brief functional
campaign, not evidence of exhaustive coverage or a security assessment.

The standalone adapter test checks distinct file contents and empty/short input
at the callback boundary. `zig build fuzz-corpus` executes all seed files,
including zero and equal halves. Add mode-level targets for counter/section
boundaries, streaming splits, aliases and authentication-failure preservation
when extending coverage. Compiler instrumentation and runtime support must be
verified rather than inferred from these dumb-mode results.

## Running and replaying

Install AFL++ using your platform's package manager (for example,
`apt install afl++` on Debian/Ubuntu). Dumb mode needs `afl-fuzz`;
QEMU mode additionally needs a working `afl-qemu-trace` runtime, which is not
included in every package. Setting `AFL_CC` or `AFL_CXX` does not instrument
these Zig binaries.

```sh
./scripts/fuzz-dumb.sh key_schedule
./scripts/fuzz-qemu.sh roundtrip
./scripts/fuzz-parallel.sh ls_roundtrip dumb 2
./scripts/fuzz-reproduce.sh key_schedule path/to/saved/input
zig-out/bin/key_schedule test/fuzz/corpus/key_schedule/zero_key
```

Parallel dumb workers use separate output directories because AFL rejects
synchronization flags in that mode. QEMU workers use AFL's master/secondary
synchronization. The runner stops only its own background jobs. Replay returns
the target's exit status. The QEMU and parallel runner argument handling is
regression-tested with stand-ins; the recorded real campaign used dumb mode.
