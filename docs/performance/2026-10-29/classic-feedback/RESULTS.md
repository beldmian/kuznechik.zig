# Retained feedback changes — measured results

Zig 0.15.1 ReleaseFast; Boat Ryzen 9 9950X; 16 KiB complete operations, whole update. Ratios are elapsed optimized / elapsed v0.8.0, lower is better. Each value is the median of three run medians, each from seven alternating measured pairs after two warmup pairs.

| Operation | Native ratio | Portable-target ratio |
| --- | ---: | ---: |
| OFB-xor, m=1 | 0.985 | 1.000 |
| OFB-xor, m=16 | 1.010 | 0.998 |
| OFB-xor, m=64 | 0.773 | 0.962 |
| OFB-xor, m=65 | 0.711 | 0.951 |

See `summary.json` for every short/long/split cell, per-run ratios and run ranges; `summary.txt` explicitly lists all ratios above 1.05. CFB, CMAC and OFB m=1/2/3/4/8/16 retain their original algorithms and serve as controls.

All 73 original native root tests plus three new tests pass in ReleaseSafe and ReleaseFast: **76/76**. Portable root ReleaseSafe: **68 passed, 2 GFNI skips**, versus baseline 65 passed and 2 skips. The final local `zig build test -Doptimize=ReleaseSafe` also reports 68 passed, 2 skips. Static contracts confirm Cipher=352 bytes and unchanged mode sizes/alignments/field offsets.

No allocation or public field change; ACPKM source is untouched. CFB production source is identical to baseline: its vector variants were rejected because small split operations regressed. OFB groups XOR and ring bookkeeping only for IVs of at least 64 blocks and runs of at least four already-generated blocks. CMAC direct-block processing was rejected for insufficient repeatable gain; its production source is identical to baseline.

Scope: one virtualized Zen 5 machine, two compiler CPU targets, the measured seeds, lengths and partitions. Portable is the generic compiler backend on that same machine. Code-size and layout affect tiny messages; earlier CFB candidates and the OFB width-16 specialization were rejected after those controls. No universal speed or physical-optimality claim. VM contention/frequency effects and individual sample outliers remain possible.

## Regression check

No changed OFB configuration exceeds 1.05 in the median of three run medians. Individual noisy run cells are listed without omission in `summary.txt`; this threshold does not establish zero overhead for every possible workload.
