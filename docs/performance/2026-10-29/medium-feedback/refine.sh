#!/bin/bash
set -euo pipefail
cd /home/user/medium-feedback
zig=/home/user/zig-x86_64-linux-0.15.1/zig
cp variants/threshold-noinline-scalar.zig src/modes/classic.zig
mkdir -p evidence/noinline
for target in native baseline; do
 "$zig" build-exe -O ReleaseFast -mcpu="$target" --cache-dir /home/user/.cache/medium-refine-local --global-cache-dir /home/user/.cache/medium-refine-global -Mroot=short-paired.zig -femit-bin="short-$target"
 taskset -c 0 "./short-$target" 271828 131072 99 0 2>"evidence/noinline/$target-forward1.jsonl"
 taskset -c 0 "./short-$target" 314159 131072 99 3 2>"evidence/noinline/$target-forward2.jsonl"
done
