# Experiment history

All cipher kernels in this investigation come from released v0.9.0,
`d42d82cd4ece09b6281aac58cdcbe6edef5d43b7`. Historical feedback/OFB
experiments informed the dispatcher choice, but their timing ratios are not
baselines here and are not combined with these gains.

1. **Initial implementation error (not a performance result).** New
   `const count = @min(64, iv_blocks, remaining / 16)` inferred a narrow integer
   type. Multiplying it by 16 overflowed in ReleaseSafe; the ReleaseFast pilot
   stopped progressing at its first large-IV batch. Both loops were corrected
   to `const count: usize`. The failing local test log and interrupted VM pilot
   are retained. Reproduce the faulty source by removing `: usize` from the two
   new batch counts in `variants/inline-classic.zig`. No pilot samples enter
   any summary. Early benchmark build attempts also exposed Zig's prohibition
   on one file belonging to multiple modules; the final drivers import both
   versions within one root module, preserving the baseline file verbatim.
2. **Automatic helper inlining.** `variants/inline-classic.zig` and
   `variants/inline-results/` preserve the corrected implementation and six
   run sets. Both encryption modes batch with every IV width >=64. LLVM
   incorporated the large batch bodies into the public encryption functions.
   The portable IV65 whole-16-byte CFB control regressed by about 7% (run
   medians 1.067/1.070/1.077). Rejected.
3. **Noinline batch helpers, all large widths.**
   `variants/noinline-all-widths-classic.zig` and
   `variants/noinline-all-widths-results/` preserve this candidate. Separate
   helpers remove their 64-block temporary arrays from short calls. The
   portable IV65 whole-16-byte CFB control still regressed: ratios
   1.04665/1.06085/1.07322 (aggregate 1.06085). Large CFB encryption was faster,
   but that dispatch coverage was rejected because of the control regression.
4. **Compiler-hint probes (compile only).** `force-crypt-classic.zig` forces
   the existing scalar crypt helper inline at its call site;
   `hot-classic.zig` adds a likely hint at encryption entry;
   `hint-classic.zig` marks the batch branch unlikely. The first two retained
   the same 0x212-byte portable IV65 encryption function; the last produced
   0x21f bytes. None entered production or performance conclusions. Declaring
   the public method `inline` was also excluded because it changes Zig's
   calling convention, breaking ordinary function-pointer compatibility.
5. **Conservative CFB register selection.** CBC keeps all IV widths >=64;
   CFB batches only power-of-two IV widths >=64. IV65 CFB uses the original
   scalar encryption algorithm. Both methods use separate noinline batch
   helpers and dispatch only updates >=64 bytes. This is the final candidate
   measured in the top-level JSONL files. The measured eligible CFB widths
   are 64 and 128; no speed claim extends to unmeasured widths.

No generic per-block CFB vector rewrite was attempted. Batched CFB writes
`stream` and `feedback` exactly as scalar encryption would, including when
`used == 16`; full-block inverse processing retains its pre-existing behavior.
The independent tests check observable state, and the separate continuation
check compares every context field against v0.9.0 while alternating encryption
and decryption on a continuing context.

An intermediate validation runner was edited while its shell was still reading
it. Its six candidate native/portable suites completed, but the following
AArch64 command was truncated by the changed file offsets (`al-cache-dir:
command not found`, retained in that variant's log). This was a runner failure,
not a successful cross-compilation receipt. The final runner was transferred
only after the preceding process exited, and the final matrix, cross-build,
layout and continuation checks were executed again from that stable script.
