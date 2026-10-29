#!/bin/bash
set -euo pipefail
cd /home/user/gfni-pair
Z=/home/user/zig-x86_64-linux-0.15.1/zig
export ZIG_GLOBAL_CACHE_DIR=/home/user/.cache/gfni-pair-retained/global
export ZIG_LOCAL_CACHE_DIR=/home/user/.cache/gfni-pair-retained/local
mkdir -p retained
for name in bench reverse; do
 "$Z" build-exe "$name.zig" -O ReleaseFast -mcpu=native -fllvm -femit-bin="bin-$name" -femit-asm="$name.s" >"retained/build-$name.log" 2>&1
done
for spec in 'bench 745123 0' 'reverse 912345 3' 'bench 221133 2' 'reverse 745123 0' 'bench 912345 3' 'reverse 221133 2'; do
 read -r name seed layout <<< "$spec"
 taskset -c 1 "./bin-$name" "$seed" "$layout" 524288 21 >"retained/$name-$seed-$layout.jsonl" 2>&1
done
bash validate.sh >retained-validation-audit.jsonl 2>&1
