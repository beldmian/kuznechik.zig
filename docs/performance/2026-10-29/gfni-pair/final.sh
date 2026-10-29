#!/bin/bash
set -euo pipefail
cd /home/user/gfni-pair
Z=/home/user/zig-x86_64-linux-0.15.1/zig
export ZIG_GLOBAL_CACHE_DIR=/home/user/.cache/gfni-pair-final/global
export ZIG_LOCAL_CACHE_DIR=/home/user/.cache/gfni-pair-final/local
mkdir -p final
for name in bench narrow control reverse; do
 "$Z" build-exe "$name.zig" -O ReleaseFast -mcpu=native -fllvm -femit-bin="bin-$name" -femit-asm="$name.s" >"final/build-$name.log" 2>&1
done
for spec in 'bench 745123 0' 'reverse 912345 3' 'bench 221133 2' 'reverse 745123 0' 'bench 912345 3' 'reverse 221133 2' 'control 745123 0' 'control 912345 3'; do
 read -r name seed layout <<< "$spec"
 taskset -c 1 "./bin-$name" "$seed" "$layout" 524288 21 >"final/$name-$seed-$layout.jsonl" 2>&1
done
"$Z" build-exe bench.zig -O ReleaseFast -mcpu=baseline -fllvm -femit-bin=bin-portable >final/build-portable.log 2>&1
for spec in '745123 0' '912345 3'; do
 read -r seed layout <<< "$spec"
 taskset -c 1 ./bin-portable "$seed" "$layout" 131072 11 >"final/portable-$seed-$layout.jsonl" 2>&1
done
bash validate.sh >validation-audit.jsonl 2>&1
