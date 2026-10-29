#!/bin/bash
set -euo pipefail
cd /home/user/gfni-pair
Z=/home/user/zig-x86_64-linux-0.15.1/zig
export ZIG_GLOBAL_CACHE_DIR=/home/user/.cache/gfni-pair-controls/global
export ZIG_LOCAL_CACHE_DIR=/home/user/.cache/gfni-pair-controls/local
mkdir -p controls
for name in wide-control inside inside-reverse switch switch-reverse; do
 "$Z" build-exe "$name.zig" -O ReleaseFast -mcpu=native -fllvm -femit-bin="bin-$name" -femit-asm="$name.s" >"controls/build-$name.log" 2>&1
 for spec in '745123 0' '912345 3'; do
  read -r seed layout <<< "$spec"
  taskset -c 1 "./bin-$name" "$seed" "$layout" 131072 15 >"controls/$name-$seed-$layout.jsonl" 2>&1
 done
done
