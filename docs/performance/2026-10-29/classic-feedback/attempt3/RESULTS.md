# Retained feedback changes — measured results

Zig 0.15.1 ReleaseFast; Boat Ryzen 9 9950X; 16 KiB complete operations, whole update. Ratios are elapsed optimized / elapsed v0.8.0, lower is better. Each value is the median of three run medians, each from seven alternating measured pairs after two warmup pairs.

| Operation | Native ratio | Portable-target ratio | Native ns/op before → after |
| --- | ---: | ---: | ---: |
| CFB-encrypt, m=1 | 0.892 | 0.961 | 63581 → 56452 |
| CFB-encrypt, m=2 | 0.862 | 0.890 | 57475 → 50693 |
| CFB-encrypt, m=3 | 0.851 | 0.895 | 57535 → 48939 |
| CFB-encrypt, m=65 | 0.850 | 0.893 | 58913 → 51202 |
| OFB-xor, m=16 | 0.915 | 0.959 | 10823 → 9960 |
| OFB-xor, m=64 | 0.776 | 0.968 | 4906 → 3849 |
| OFB-xor, m=65 | 0.714 | 0.950 | 6516 → 4604 |

See `summary.json` for every short/long/split cell, per-run ratios and run ranges; `summary.txt` explicitly lists all ratios above 1.05. OFB m=1/2/3/4/8 and CMAC retain their original algorithms and serve as controls.

All 73 original native root tests plus three new tests pass in ReleaseSafe and ReleaseFast: **76/76**. Portable root ReleaseSafe: **68 passed, 2 GFNI skips**, versus baseline 65 passed and 2 skips. The final local `zig build test -Doptimize=ReleaseSafe` also reports 68 passed, 2 skips. Static contracts confirm Cipher=352 bytes and unchanged mode sizes/alignments/field offsets.

No allocation or public field change; ACPKM source is untouched. CFB still performs serial dependent encryptions, with complete-block vector XOR/feedback and a short-update specialization. OFB groups XOR and ring bookkeeping only for IVs of at least 16 blocks and runs of at least four already-generated blocks. CMAC direct-block processing was rejected for insufficient repeatable gain.

Scope: one virtualized Zen 5 machine, two compiler CPU targets, the measured seeds, lengths and partitions. Portable is the generic compiler backend on that same machine. Code-size and layout affect tiny messages; the private noinline CFB helper is an empirical compiler-sensitive choice. No universal speed or physical-optimality claim. VM contention/frequency effects and individual sample outliers remain possible.

## Regression check

The following cells exceed 1.05 across the three-run median and require an explicit retention decision:
- native CFB-encrypt m=2, bytes=16, split1=True: 1.054
- native OFB-xor m=16, bytes=64, split1=True: 1.058
