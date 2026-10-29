#!/bin/sh
set -eu
cd /home/user/kuz-gfni-spills
export ZIG_LOCAL_CACHE_DIR=$(mktemp -d /home/user/.cache/kuz-schedules-local.XXXXXX)
export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d /home/user/.cache/kuz-schedules-global.XXXXXX)
z=/tmp/zig-x86_64-linux-0.15.1/zig
for v in first8 dfs-forward dfs-forward-r dfs-reverse dfs-reverse-r dfs-paired dfs-paired-r dfs-paired-reverse dfs-paired-reverse-r; do
 taskset -c 2 "$z" build-obj "$v/codegen.zig" -OReleaseFast -mcpu=native -femit-bin="$v-codegen.o" -femit-asm="$v-codegen.s"
done
