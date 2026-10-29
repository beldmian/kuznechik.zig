#!/bin/bash
set -euo pipefail
cd /home/user/medium-feedback
zig=/home/user/zig-x86_64-linux-0.15.1/zig
mkdir -p evidence/excluded
for target in native baseline; do
 for placement in forward reverse; do
  source=excluded-paired.zig
  if [ "$placement" = reverse ]; then source=excluded-reversed.zig; fi
  "$zig" build-exe -O ReleaseFast -mcpu="$target" --cache-dir /home/user/.cache/medium-excluded-local --global-cache-dir /home/user/.cache/medium-excluded-global -Mroot="$source" -femit-bin="excluded-$target-$placement"
 done
 taskset -c 0 "./excluded-$target-forward" 271828 131072 99 0 2>"evidence/excluded/$target-forward1.jsonl"
 taskset -c 0 "./excluded-$target-forward" 314159 131072 99 3 2>"evidence/excluded/$target-forward2.jsonl"
 taskset -c 0 "./excluded-$target-reverse" 1618033 131072 99 1 2>"evidence/excluded/$target-reverse.jsonl"
done
