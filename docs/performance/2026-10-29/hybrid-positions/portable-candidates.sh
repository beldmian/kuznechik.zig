#!/bin/bash
set -euo pipefail
cd /home/t3/.cache/kuz-hybrid-positions/stage
z=/tmp/kuz-toolchains/zig-x86_64-linux-0.15.1/zig
export ZIG_LOCAL_CACHE_DIR=$(mktemp -d /home/t3/.cache/kuz-hybrid-positions/candidate-test-local.XXXXXX)
export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d /home/t3/.cache/kuz-hybrid-positions/candidate-test-global.XXXXXX)
printf '%s\n' "$ZIG_LOCAL_CACHE_DIR" "$ZIG_GLOBAL_CACHE_DIR" > candidate-local-test-caches.txt
for v in boundary spaced split2; do
 for opt in Debug ReleaseSafe ReleaseFast; do
  "$z" test "$v/kuznechik.zig" -O"$opt" -mcpu=x86_64 -fllvm > "$v-portable-$opt.log" 2>&1
 done
 "$z" test "$v/kuznechik.zig" -OReleaseFast -target aarch64-linux-musl -fllvm -fno-emit-bin > "$v-aarch64.log" 2>&1
done
