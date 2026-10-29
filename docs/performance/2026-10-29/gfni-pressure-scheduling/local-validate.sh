#!/bin/sh
set -eu
stage=$1
z=/tmp/kuz-toolchains/zig-x86_64-linux-0.15.1/zig
export ZIG_LOCAL_CACHE_DIR=$(mktemp -d /home/t3/.cache/gfni-pressure-test-local.XXXXXX)
export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d /home/t3/.cache/gfni-pressure-test-global.XXXXXX)
printf '%s\n' "$ZIG_LOCAL_CACHE_DIR" "$ZIG_GLOBAL_CACHE_DIR" > "$stage/baseline-local-caches.txt"
for v in baseline; do
 for opt in Debug ReleaseSafe ReleaseFast; do
  "$z" test "$stage/$v/kuznechik.zig" -O"$opt" -mcpu=baseline -fllvm > "$stage/$v-portable-$opt.log" 2>&1
 done
 "$z" test "$stage/$v/kuznechik.zig" -OReleaseFast -target aarch64-linux-musl -fllvm --test-no-exec -femit-bin="$stage/$v-aarch64-test" > "$stage/$v-aarch64.log" 2>&1
 file "$stage/$v-aarch64-test" > "$stage/$v-aarch64-file.txt"
done
