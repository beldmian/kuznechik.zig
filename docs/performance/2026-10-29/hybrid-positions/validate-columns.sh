#!/bin/bash
set -euo pipefail
z=${ZIG:-/home/user/hybrid-positions/toolchain/zig}
cache_root=${CACHE_ROOT:-/home/user/.cache/hybrid-positions}
export ZIG_LOCAL_CACHE_DIR=$(mktemp -d "$cache_root"/columns-local.XXXXXX)
export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d "$cache_root"/columns-global.XXXXXX)
printf '%s\n' "$ZIG_LOCAL_CACHE_DIR" "$ZIG_GLOBAL_CACHE_DIR" > columns-caches.txt
for v in prefix suffix high_prefix low_suffix edge_mix boundary outer split3 split2 spaced spaced_end even odd ends middle high_edges; do
 taskset -c 2 "$z" test "$v/hybrid.zig" -OReleaseFast -mcpu=native -fllvm > "columns-$v.log" 2>&1
done
