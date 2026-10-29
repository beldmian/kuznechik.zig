# Reproduction and boundaries

Start from exact released v0.9.2, commit
`69d7ed3a2db775071fe331eb667b84283eaafb0d`. `baseline-v0.9.2.tar.gz`
is a `git archive` of that commit's src/build files, never a Git checkout.
`prepare.py` extracts that archive into the source-only directory
`/home/t3/.cache/kuz-medium-feedback`, preserves the original classic module as
`src/modes/classic_before_092.zig`, and overlays the candidate classic module.

```sh
python3 docs/performance/2026-10-29/medium-feedback/prepare.py
boat new --no-env --no-snapshots --ttl 10800 --name kuz-medium-feedback --json
# This run was assigned bx_g86mt7cz. Parse each JSONL event separately.
boat ssh bx_g86mt7cz 'mkdir -p /home/user/medium-feedback /home/user/.cache/medium-feedback'
boat scp /home/t3/.cache/kuz-other-toolchains/zig.tar.xz bx_g86mt7cz:/home/user/zig.tar.xz
boat ssh bx_g86mt7cz 'cd /home/user && tar xf zig.tar.xz && sha256sum zig.tar.xz zig-x86_64-linux-0.15.1/zig'
boat scp -r /home/t3/.cache/kuz-medium-feedback/. bx_g86mt7cz:/home/user/medium-feedback/
# boat scp adds the source basename directory; flatten its contents once.
boat ssh bx_g86mt7cz 'mv /home/user/medium-feedback/kuz-medium-feedback/* /home/user/medium-feedback/ && rmdir /home/user/medium-feedback/kuz-medium-feedback'
boat ssh bx_g86mt7cz 'cd /home/user/medium-feedback && bash run.sh && bash control.sh && bash run-excluded.sh && bash run-tests.sh && bash after.sh'
```

The standalone `candidate-source.tar.gz` contains the complete final source-only
folder with all drivers, exact baseline archive, scripts and reversed placement
driver. Extract it at `/home/user/medium-feedback` and run those same scripts.
The archive does not include toolchains or Git metadata. All caches use unique
disk-backed paths under `/home/t3/.cache` or `/home/user/.cache`; no large tmpfs
cache is used. Timing and compilation/validation on the VM are serialized.

`run.sh` builds ReleaseFast with `-mcpu=native` and `-mcpu=baseline`, then runs
three seeds/placements per target, pinned to CPU 0. Seed/layout combinations are
271828/0, 314159/3 and reversed 1618033/1. Layouts 3/1 are unaligned by one byte;
layout 3 swaps output buffers. The reversed driver swaps module declaration
order and semantic labels. Analysis inverts those pair ratios.

Each repetition includes plaintext copying, public context init (including
cipher and IV-register copies), and public encrypt calls. Key expansion,
allocation, random generation, comparison and checksums are outside timing.
Whole operations use one call; split operations use two, after byte 1 for CFB
or block 1 for CBC. Thus tiny split CFB includes a pending partial-block
continuation, and long splits finish pending feedback before any batching.
The second call may be empty. Every pair compares full output and hashes every
output byte after timing, and memory barriers prevent dead-code elimination.
Runtime keys/IVs/plaintext depend on each seed. AES is a correctness adapter,
not a timing target.

Each cell has two warmup pairs, then nine alternating measured pairs. The
budget is 131072 plaintext bytes, with at least eight repetitions per timed
sample. There are 1088 rows per final run, including repeated lengths where a
fixed length equals a ring boundary. Analysis pools the nine pair ratios for
such duplicate rows within a run, then takes the median of the three run
medians. Repetitions are retained in raw logs. `excluded-paired.zig` / `excluded-reversed.zig` use the shorter length grid for
unlisted widths 5/7/9/15/17/23/25/30/33/62, two forward seeds and reversed placement.
`run-excluded.sh` is the standalone extraction of the excluded-width build/run
commands in `restrict.sh`; run it before `after.sh` in a clean reproduction.
This convenience script was extracted locally after VM cleanup; its body is
identical to the recorded commands already executed by `restrict.sh`.
`restrict.sh` records the transition from the broader CBC range to the explicit
nine-width selector and re-runs the exact final matrix and validation. It assumes
that the preceding broader run exists; clean reproduction uses `run.sh`, `control.sh`, `run-excluded.sh`,
`run-tests.sh` and `after.sh` directly.

`control.sh` uses two separate
verbatim copies of baseline classic code and a shorter length grid; it measures
unchanged baseline-versus-baseline in both compiler targets on the same CPU.
After validation, `after.sh` adds seeds 314159/layout3 and 1618033/layout1 with
that same forward control binary. It also adds excluded-width seeds
424242/layout0 and reversed 8675309/layout3, after an outlying initial unchanged
CFB62 short control prompted confirmation. All original samples remain in the
five-run excluded-width summaries. It then emits assembly/symbol captures and source
hashes. It never overlaps a compile or timing run on the VM. For clean source
reproduction, run `bash after.sh` after `run-tests.sh`; its variant sources are
in the bundle.

The initial `pilot.sh` used 32768-byte budgets, five measured pairs after two
warmups, and the eight-length initial grid; `variants/pilot/` keeps its raw data.
`variants/threshold-inline/` uses the final full grid; `variants/noinline/`,
`vector-scalar/` and `inside-dispatch/` use `short-paired.zig` with two seeds
per target. Their exact candidate sources are in `variants/*.zig`.
For a source variant, copy it over src/modes/classic.zig in the source-only
folder and build the appropriate driver with the same command in `run.sh`.
The initial pilot driver is retained as `pilot-paired.zig`.

```sh
python3 docs/performance/2026-10-29/medium-feedback/analyze.py
python3 docs/performance/2026-10-29/medium-feedback/verify.py
```

`run-tests.sh` records baseline optimized inventories, full final native and
portable Debug/Safe/Fast, explicit LLVM native Debug, two feature-gate profiles,
a linked AArch64 test executable, and independent layout/direction continuation
checks. Every invocation uses fresh local and global caches. Performance logs
are separate from these validation logs. The actual named entries and skip
counts are retained; a cached binary's exit status alone is not validation.

`transport-note.txt` records a local SSH-client exit 143 while the remote final
runner continued. A fresh read-only process check confirmed the existing runner;
no duplicate was started. Final logs and marker files establish completion.
