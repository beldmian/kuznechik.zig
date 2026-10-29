# OFB integration with the released 70-map cipher

Root follow-up to the [feedback experiments](../classic-feedback/RESULTS.md).
The original candidate was measured with the older 75-map block kernel.
These paired comparisons use the v0.8.1 70-map cipher for both mode versions,
isolating OFB bookkeeping. They precede the separate output-operand change
released in v0.9.0; gains from those experiments must not be added together.

## Rejected first integration

`forward1.jsonl`, `forward2.jsonl`, `reverse.jsonl` and `summary.json`
preserve the first root confirmation. With a 64-block IV, a 16-byte message
split after its first byte had candidate/baseline median time ratios
1.05017, 1.05494 and 1.07475. This candidate was rejected.

## Retained refinement

The public `xor` method dispatches updates of at least 64 bytes to the batched
loop only for IV registers of at least 64 blocks. All other updates use the
original scalar loop. Fields, partial keystream, cipher calls and outputs
are unchanged. `classic-retained.zig` is the exact integrated source.

The three `dispatch*.jsonl` files contain 64 cases each: IV widths
1/2/3/4/8/16/64/65, lengths 16/64/1024/16384, whole messages and a split after
one byte. Each case has 15 alternating measured pairs after two warmups.
Two runtime seeds change keys, IVs and inputs; the third also reverses module
placement. Buffer placement and alignment vary. Every full output and tag is
compared, and every byte contributes to a checksum.

`analyze.py` computes ratios per pair, then medians per run, then the median
of the three run medians. It inverts the reversed module labels. Among changed
cases the largest resulting median ratio is 0.996064; unchanged controls reach
1.004002. This supports retaining the refinement in the tested configurations,
without resolving tiny differences within timing noise.

For whole 16 KiB messages, the 64-block IV ratios are
0.742570/0.732638/0.759598 (median 0.742570, 25.7% less time).
The 65-block IV ratios are 0.699092/0.666556/0.695468
(median 0.695468, 30.5% less time). These are elapsed-time reductions,
including context initialization, input copying and mode processing; key
expansion and allocation are outside the timed region.

## Reproduction

Boat `bx_758ez2tt`, AMD Ryzen 9 9950X guest, Zig 0.15.1,
ReleaseFast, `-mcpu=native`, pinned to core 0. `lscpu.json` records the guest.
The compiler archive and executable SHA-256 values are recorded in the
[v0.9.0 integration receipt](../../../validation/v0.9.0/README.md).

Use a source-only copy of v0.8.1. Replace its `src/modes/classic.zig` with
`classic-retained.zig`; save `before.zig` as
`src/modes/classic_before_082.zig`. Keep the measured cipher kernel (also
saved as `toeplitz-core-measured.zig`), rather than the later operand change.
Copy both paired drivers to that source copy's root. Then:

```sh
zig build-exe -O ReleaseFast -mcpu=native --dep kuz --dep before \
  -Mroot=paired.zig -Mkuz=src/kuznechik.zig \
  -Mbefore=src/modes/classic_before_082.zig -femit-bin=paired
taskset -c 0 ./paired 271828 1048576 1 0 2>dispatch1.jsonl
taskset -c 0 ./paired 314159 1048576 1 3 2>dispatch2.jsonl
zig build-exe -O ReleaseFast -mcpu=native --dep kuz --dep before \
  -Mroot=paired-reversed.zig -Mkuz=src/kuznechik.zig \
  -Mbefore=src/modes/classic_before_082.zig -femit-bin=paired-reversed
taskset -c 0 ./paired-reversed 1618033 1048576 1 1 2>dispatch-reverse.jsonl
python3 analyze.py
```

Final combined source passes 99 native tests in ReleaseSafe/ReleaseFast and
91 portable tests with two expected skips in Debug/ReleaseSafe, including the
independent shift-register and streaming checks. Historical `native-safe.log`
predates the complete profile integration; final logs are in the release receipt.
This is finite evidence on one guest/compiler, with no physical-optimality claim.
