# Project instructions

Kuznechik is a Zig block cipher library with allocation-free cipher modes. The
public entry points are `src/kuznechik.zig` and `src/modes/root.zig`.

Preserve the 352-byte Cipher layout and existing block APIs. Keep acceleration
behind complete target-feature and backend gates. Modes accept unaligned bytes;
validate before writes and authenticate before modifying ciphertext on opens.
Use `zig fmt`, appropriate correctness/reference checks and scoped measurements.
Default cipher/key-expansion paths are not claimed constant-time.

See `docs/OPEN-WORK.md` for remaining work and `docs/performance`,
`docs/validation` and `docs/reviews` for evidence. Performance claims should
identify the compiler, CPU, workload, source and baseline; a finite test set
does not prove optimality.
