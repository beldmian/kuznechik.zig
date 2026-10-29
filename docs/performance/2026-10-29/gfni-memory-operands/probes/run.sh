#!/bin/sh
# Independent tiny lowering probes, never used as cipher timing candidates.
set -u
z=${ZIG:-/tmp/kuz-toolchains/zig-x86_64-linux-0.15.1/zig}
cd "$(dirname "$0")"
export ZIG_LOCAL_CACHE_DIR=$(mktemp -d /home/t3/.cache/gfni-memory-probes-local.XXXXXX)
export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d /home/t3/.cache/gfni-memory-probes-global.XXXXXX)
printf '%s\n' "$ZIG_LOCAL_CACHE_DIR" "$ZIG_GLOBAL_CACHE_DIR" > caches.txt
for v in probe indirect value aggregate; do
 "$z" build-obj "$v.zig" -OReleaseFast -mcpu=znver5 -femit-llvm-ir="$v.ll" -femit-asm="$v.s" -femit-bin="$ZIG_LOCAL_CACHE_DIR/$v.o" > "$v.log" 2>&1
 echo "$v exit=$?"
done
