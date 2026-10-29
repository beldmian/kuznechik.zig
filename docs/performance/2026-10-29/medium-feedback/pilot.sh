#!/bin/bash
set -euo pipefail
cd /home/user/medium-feedback
zig=/home/user/zig-x86_64-linux-0.15.1/zig
mkdir -p evidence/pilot
for target in native baseline; do
 "$zig" build-exe -O ReleaseFast -mcpu="$target" --cache-dir /home/user/.cache/medium-pilot-local --global-cache-dir /home/user/.cache/medium-pilot-global -Mroot=paired.zig -femit-bin="pilot-$target"
 taskset -c 0 "./pilot-$target" 271828 32768 99 0 2>"evidence/pilot/$target.jsonl"
done
