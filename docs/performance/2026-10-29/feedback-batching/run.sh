#!/bin/bash
set -euo pipefail
cd /home/user/kuz-feedback-next
zig=/tmp/zig-x86_64-linux-0.15.1/zig
export ZIG_GLOBAL_CACHE_DIR=/home/user/.cache/feedback-global
mkdir -p evidence /home/user/.cache/feedback-build
for target in native baseline; do
  for placement in forward reverse; do
    source=paired.zig
    if [ "$placement" = reverse ]; then source=paired-reversed.zig; fi
    "$zig" build-exe -O ReleaseFast -mcpu="$target" --cache-dir /home/user/.cache/feedback-build -Mroot="$source" -femit-bin="paired-$target-$placement"
  done
  taskset -c 0 "./paired-$target-forward" 271828 262144 99 0 2>"evidence/$target-forward1.jsonl"
  taskset -c 0 "./paired-$target-forward" 314159 262144 99 3 2>"evidence/$target-forward2.jsonl"
  taskset -c 0 "./paired-$target-reverse" 1618033 262144 99 1 2>"evidence/$target-reverse.jsonl"
done
