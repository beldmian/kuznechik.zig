#!/bin/sh
set -eu
cd /home/user/kuz-gfni-pressure
export ZIG_LOCAL_CACHE_DIR=$(mktemp -d /home/user/.cache/gfni-pressure-screen-local.XXXXXX)
export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d /home/user/.cache/gfni-pressure-screen-global.XXXXXX)
printf '%s\n' "$ZIG_LOCAL_CACHE_DIR" "$ZIG_GLOBAL_CACHE_DIR" > screen-caches.txt
z=/home/user/zig-x86_64-linux-0.15.1/zig
for v in baseline ready*; do
 [ -d "$v" ] || continue
 cp codegen.zig "$v/codegen.zig"
 taskset -c 2 "$z" build-obj "$v/codegen.zig" -OReleaseFast -mcpu=native -femit-bin="$v-codegen.o" -femit-asm="$v-codegen.s"
 echo "screened $v"
done
