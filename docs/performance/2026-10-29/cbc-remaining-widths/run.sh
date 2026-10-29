#!/bin/bash
set -euo pipefail
cd /home/user/cbc-widths
zig=/home/user/zig-x86_64-linux-0.15.1/zig
mkdir -p evidence/final evidence/control
for target in native baseline; do
 for placement in forward reverse control; do
  source=paired.zig
  if [ "$placement" = reverse ]; then source=paired-reversed.zig; fi
  if [ "$placement" = control ]; then source=paired-control.zig; fi
  "$zig" build-exe -O ReleaseFast -mcpu="$target" --cache-dir /home/user/.cache/cbc-bench-local --global-cache-dir /home/user/.cache/cbc-bench-global -Mroot="$source" -femit-bin="paired-$target-$placement"
 done
 taskset -c 0 "./paired-$target-forward" 271828 65536 0 2>"evidence/final/$target-forward1.jsonl"
 taskset -c 0 "./paired-$target-forward" 314159 65536 3 2>"evidence/final/$target-forward2.jsonl"
 taskset -c 0 "./paired-$target-reverse" 1618033 65536 1 2>"evidence/final/$target-reverse.jsonl"
 # Baseline-v-baseline checks use identical public-API boundaries and full grid.
 taskset -c 0 "./paired-$target-control" 271828 65536 0 2>"evidence/control/$target-forward1.jsonl"
 taskset -c 0 "./paired-$target-control" 314159 65536 3 2>"evidence/control/$target-forward2.jsonl"
 taskset -c 0 "./paired-$target-control" 1618033 65536 1 2>"evidence/control/$target-forward3.jsonl"
done
printf 'ALL TIMING COMMANDS PASSED\n' > evidence/timing-complete.txt
