#!/bin/bash
set -euo pipefail
cd /home/t3/.cache/kuz-hybrid-positions/stage
z=/tmp/kuz-toolchains/zig-x86_64-linux-0.15.1/zig
export ZIG_LOCAL_CACHE_DIR=$(mktemp -d /home/t3/.cache/kuz-hybrid-positions/test-local.XXXXXX)
export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d /home/t3/.cache/kuz-hybrid-positions/test-global.XXXXXX)
printf '%s\n' "$ZIG_LOCAL_CACHE_DIR" "$ZIG_GLOBAL_CACHE_DIR" > local-test-caches.txt
for opt in Debug ReleaseSafe ReleaseFast; do
 "$z" test baseline/kuznechik.zig -O"$opt" -mcpu=x86_64 -fllvm > "baseline-portable-$opt.log" 2>&1
done
"$z" test baseline/kuznechik.zig -OReleaseFast -target aarch64-linux-musl -fllvm -fno-emit-bin > baseline-aarch64.log 2>&1
