#!/bin/bash
set -euo pipefail
cd /home/user/medium-feedback
zig=/home/user/zig-x86_64-linux-0.15.1/zig
mkdir -p evidence/final
for target in native baseline; do
 for placement in forward reverse; do
  source=paired.zig
  if [ "$placement" = reverse ]; then source=paired-reversed.zig; fi
  "$zig" build-exe -O ReleaseFast -mcpu="$target" --cache-dir /home/user/.cache/medium-final-local --global-cache-dir /home/user/.cache/medium-final-global -Mroot="$source" -femit-bin="paired-$target-$placement"
 done
 taskset -c 0 "./paired-$target-forward" 271828 131072 99 0 2>"evidence/final/$target-forward1.jsonl"
 taskset -c 0 "./paired-$target-forward" 314159 131072 99 3 2>"evidence/final/$target-forward2.jsonl"
 taskset -c 0 "./paired-$target-reverse" 1618033 131072 99 1 2>"evidence/final/$target-reverse.jsonl"
done
