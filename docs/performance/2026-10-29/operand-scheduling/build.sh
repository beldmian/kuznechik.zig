#!/bin/sh
set -eu
cd /home/user/kuz-gfni-spills
export ZIG_LOCAL_CACHE_DIR=$(mktemp -d /home/user/.cache/kuz-spills-local.XXXXXX)
export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d /home/user/.cache/kuz-spills-global.XXXXXX)
printf '%s\n' "$ZIG_LOCAL_CACHE_DIR" "$ZIG_GLOBAL_CACHE_DIR" > caches.txt
z=/tmp/zig-x86_64-linux-0.15.1/zig
for v in baseline candidate; do
 taskset -c 2 "$z" build-obj "$v/codegen.zig" -OReleaseFast -mcpu=native -femit-bin="$v-codegen.o" -femit-asm="$v-codegen.s"
done
taskset -c 2 "$z" build-exe --dep baseline --dep candidate -OReleaseFast -mcpu=native -Mroot=pairs.zig -OReleaseFast -mcpu=native -Mbaseline=baseline/kuznechik.zig -OReleaseFast -mcpu=native -Mcandidate=candidate/kuznechik.zig -femit-bin=pairs
sha256sum "$z" pairs > binary.sha256
