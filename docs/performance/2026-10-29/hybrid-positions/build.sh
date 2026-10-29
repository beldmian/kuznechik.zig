#!/bin/bash
# Run in source-only stage on an idle Zen5 host. Disk-backed unique caches.
set -euo pipefail
z=${ZIG:-/home/user/hybrid-positions/toolchain/zig}
cache_root=${CACHE_ROOT:-/home/user/.cache/hybrid-positions}
mkdir -p "$cache_root"
export ZIG_LOCAL_CACHE_DIR=$(mktemp -d "$cache_root"/build-local.XXXXXX)
export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d "$cache_root"/build-global.XXXXXX)
printf '%s\n' "$ZIG_LOCAL_CACHE_DIR" "$ZIG_GLOBAL_CACHE_DIR" > build-caches.txt
for v in baseline control prefix suffix high_prefix low_suffix edge_mix boundary outer split3 split2 spaced spaced_end even odd ends middle high_edges; do
 taskset -c 2 "$z" build-obj "$v/codegen.zig" -OReleaseFast -mcpu=native -femit-bin="$v-codegen.o" -femit-asm="$v-codegen.s"
 if [ "$v" = baseline ]; then continue; fi
 taskset -c 2 "$z" build-exe --dep baseline --dep candidate -OReleaseFast -mcpu=native -Mroot=pairs.zig -OReleaseFast -mcpu=native -Mbaseline=baseline/kuznechik.zig -OReleaseFast -mcpu=native -Mcandidate="$v/kuznechik.zig" -femit-bin="pairs-$v"
done
sha256sum "$z" pairs-* > build-binaries.sha256
