#!/bin/bash
set -euo pipefail
cd /home/user/gfni-pair
export ZIG_GLOBAL_CACHE_DIR=/home/user/.cache/gfni-pair-fixed/global
export ZIG_LOCAL_CACHE_DIR=/home/user/.cache/gfni-pair-fixed/local
for name in fixed-switch fixed-switch-reverse; do
 /home/user/zig-x86_64-linux-0.15.1/zig build-exe "$name.zig" -O ReleaseFast -mcpu=native -fllvm -femit-bin="bin-$name" -femit-asm="$name.s" >"controls/build-$name.log" 2>&1
 for spec in '745123 0' '912345 3'; do
  read -r seed layout <<< "$spec"
  taskset -c 1 "./bin-$name" "$seed" "$layout" 262144 21 >"controls/$name-$seed-$layout.jsonl" 2>&1
 done
done
