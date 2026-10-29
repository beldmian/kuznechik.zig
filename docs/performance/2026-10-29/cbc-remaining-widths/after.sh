#!/bin/bash
set -euo pipefail
cd /home/user/cbc-widths
zig=/home/user/zig-x86_64-linux-0.15.1/zig
for target in native baseline; do
 taskset -c 0 "./paired-$target-forward" 424242 65536 0 2>"evidence/final/$target-forward3.jsonl"
 taskset -c 0 "./paired-$target-reverse" 8675309 65536 3 2>"evidence/final/$target-reverse2.jsonl"
 taskset -c 0 "./paired-$target-control" 424242 65536 0 2>"evidence/control/$target-forward4.jsonl"
 taskset -c 0 "./paired-$target-control" 8675309 65536 3 2>"evidence/control/$target-forward5.jsonl"
done
mkdir -p evidence/assembly
for target in native baseline; do
 "$zig" build-obj codegen.zig -O ReleaseFast -mcpu="$target" --cache-dir /home/user/.cache/cbc-asm-local --global-cache-dir /home/user/.cache/cbc-asm-global -femit-bin="evidence/assembly/$target.o" -femit-asm="evidence/assembly/$target.s"
 nm -S --size-sort "evidence/assembly/$target.o" >"evidence/assembly/$target.nm"
done
printf 'ALL SUPPLEMENTAL COMMANDS PASSED\n' > evidence/after-complete.txt
