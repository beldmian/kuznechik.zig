# RFC 3610 CCM counter batching

2026-10-29, Boat VM `bx_evj2atxa` (`kuz-modes-l`), AMD Ryzen 9 9950X guest,
4 vCPUs, pinned to core 0. Zig 0.15.1, `-O ReleaseFast -mcpu=native`.
The native Zen 5 block backend uses the encoded Toeplitz batch circuit.

This comparison holds CCM formatting, serial CBC-MAC, nonce, AAD, input and
key fixed. The baseline encrypts each counter with the single-block API;
the candidate uses `encryptBlocks`. Opening privately authenticates then repeats
the counter pass to preserve ciphertext on rejection. Neither includes key setup,
allocation, input copying, or output verification in timing.

Two alternating warm-up pairs precede nine alternating measured pairs per size.
The seed is supplied at runtime (123). Every ciphertext byte and tag is compared
after sealing; every plaintext byte is checked after opening. The ratio is the
median of paired candidate/baseline elapsed nanoseconds, rather than a ratio of
separately selected minima. These are measurements on one guest, not universal
performance guarantees or evidence of physical optimality.

| Bytes | Operation | Serial median ns | Batch median ns | Paired ratio | Time reduction |
|---:|---|---:|---:|---:|---:|
| 1024 | seal | 5670 | 3396 | 0.598942 | 40.1% |
| 1024 | open | 8236 | 3827 | 0.463542 | 53.6% |
| 65536 | seal | 345209 | 196258 | 0.565462 | 43.5% |
| 65536 | open | 505842 | 231806 | 0.455399 | 54.5% |
| 1048576 | seal | 5529587 | 3179333 | 0.572632 | 42.7% |
| 1048576 | open | 8173381 | 3708929 | 0.455222 | 54.5% |

Raw samples: [batch-vs-serial.jsonl](batch-vs-serial.jsonl). CPU details:
[lscpu.json](lscpu.json). Native correctness logs: [ReleaseSafe](native-safe.log)
and [ReleaseFast](native-fast.log), all 33 tests passed in each. Local Debug,
ReleaseSafe and ReleaseFast passed 25 tests with two GFNI-only skips.

Reproduce at the v0.5.0 source revision (or this commit):

```sh
cp docs/performance/modes/ccm/benchmark.zig src/.ccm_bench.zig
zig build-exe src/.ccm_bench.zig -O ReleaseFast -mcpu=native -femit-bin=/tmp/ccm-bench
taskset -c 0 /tmp/ccm-bench 123 2> /tmp/ccm-bench.jsonl
rm src/.ccm_bench.zig
```

Compiler archive SHA-256: `c61c5da6edeea14ca51ecd5e4520c6f4189ef5250383db33d01848293bfafe05`.

Measured source SHA-256:

- `src/modes/ccm.zig`: `65e9af47fc13296d379abfe84c9f4ec01a0ac58880fa7cc46e57a77bbd97beec`
- `docs/performance/modes/ccm/benchmark.zig`: `5669744c721ff331cded18e43cf12e5a8bcd58887944ec1cafe86463f163817b`
