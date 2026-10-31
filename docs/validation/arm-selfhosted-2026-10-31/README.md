# Zig 0.15.2 AArch64 self-hosted backend limitation

The full CI group reached `baseline-selfhosted-debug` twice before receiving a
runner shutdown signal (runs 41191228706 and 41192215856). That log alone does
not establish why the hosted runner shut down. The previous local compile was
no longer running when work resumed; its log was empty and the output was not
a completed ELF binary. Neither attempt is a successful test result.

A bounded diagnostic on Boat large (8 vCPU, 16 GiB, Ryzen 9 9950X) cross-compiled
the unchanged complete source for `aarch64-linux-musl`, baseline Debug,
`-fno-llvm`, using the verified official Zig 0.15.2 x86-64 distribution. The
compiler exited with SIGSEGV after 2.00 seconds, maximum child RSS 372,492 KiB.
The 240-second and 5-GiB diagnostic limits did not trigger. Exact command,
samples, receipt and wrapper are preserved in `full-probe/` and
`selfhosted-probe.py`.

Filtered builds showed explicit missing vector-ABI/codegen diagnostics for
`Cipher test` and `lookup key setup`; other filters crashed or were terminated
(`filters/`). These attempts ran sequentially with a 45-second limit and are
not runtime correctness tests. The reason for each SIGKILL is unconfirmed.

The minimal `vector-probe.zig` reproduces the decisive limitation without the
cipher or modes: `CallAbiIterator.param(@Vector(16, u8))` and
`CallAbiIterator.param(@Vector(32, u8))`. See `vector-probe.log`. The same input
and output vector forms are used by the library's public cipher and mode APIs.
Changing the public API or replacing the compiler backend is outside this repair.

`test/backend_support.zig` now probes those operations before self-hosted full
suites. The runner recognizes only the recorded AArch64 / Zig 0.15.2 / exit 1 /
matching vector-ABI diagnostics as **unsupported**, with no passing test inventory.
A crash, timeout, different compiler version, architecture, or diagnostic is a
failure. Even the known unsupported result fails by default; CI explicitly opts
in via `--allow-known-unsupported` in a dedicated `arm-selfhosted-capability` job.
If the probe succeeds, the complete suite runs normally. Complete LLVM ARM jobs
remain required and independent of this capability job.

Every full profile now has a 900-second default deadline and every capability
probe a 30-second deadline. On timeout only that measurement's process group is
terminated; exit 124 and the resource receipt are preserved. Unit regressions
exercise timeout reporting and ensure unsupported profiles cannot count as passed.

## Runner verification and resource cleanup

The updated measurement/probe runner executed the complete x86-64 native
self-hosted Debug suite on the same Boat VM: 97 passed, three feature/backend
skips, exit zero, 98.19 seconds, peak child RSS 323,516 KiB. The raw capability
probe, full inventory, source hashes, commands, resource receipts and summary
are in `runner-recheck/`; all copied checksums were verified before deletion.
This validates the runner on its supported backend and does not establish ARM
self-hosted correctness.

VM `bx_m46n8hgu` was deleted after retrieval. Deletion operation
`bdop_73a66a384f25483b8f9f497b6c4c7d07` completed at
`2026-10-31T15:35:47.355Z`; the all-state VM list was empty. The last usage
receipt before deletion was $0.00935 (about 7m48s wall time), within the prior
budget. No credentials or account security settings were created or changed.
