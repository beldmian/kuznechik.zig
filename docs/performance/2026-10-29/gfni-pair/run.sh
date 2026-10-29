#!/bin/bash
set -euo pipefail
cd /home/user/gfni-pair
Z=/home/user/zig-x86_64-linux-0.15.1/zig
export ZIG_GLOBAL_CACHE_DIR=/home/user/.cache/gfni-pair/global
export ZIG_LOCAL_CACHE_DIR=/home/user/.cache/gfni-pair/local
mkdir -p logs
for name in bench narrow control reverse; do
 "$Z" build-exe "$name.zig" -O ReleaseFast -mcpu=native -fllvm -femit-bin="bin-$name" -femit-asm="$name.s" >"logs/build-$name.log" 2>&1
 taskset -c 1 "./bin-$name" 123 0 131072 11 >"logs/$name-pilot.jsonl" 2>&1
done
