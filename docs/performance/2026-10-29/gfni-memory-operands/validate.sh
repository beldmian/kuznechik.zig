#!/bin/sh
set -eu
cd /home/user/kuz-gfni-memory
export ZIG_LOCAL_CACHE_DIR=$(mktemp -d /home/user/.cache/gfni-memory-tests-local.XXXXXX)
export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d /home/user/.cache/gfni-memory-tests-global.XXXXXX)
printf '%s\n' "$ZIG_LOCAL_CACHE_DIR" "$ZIG_GLOBAL_CACHE_DIR" > test-caches.txt
z=/home/user/zig-x86_64-linux-0.15.1/zig
for v in baseline explicit-clobber explicit-read; do
 for opt in Debug ReleaseSafe ReleaseFast; do
  taskset -c 2 "$z" test "$v/kuznechik.zig" -O"$opt" -mcpu=native -fllvm > "$v-native-$opt.log" 2>&1
  taskset -c 2 "$z" test "$v/kuznechik.zig" -O"$opt" -mcpu=baseline -fllvm > "$v-portable-$opt.log" 2>&1
 done
 taskset -c 2 "$z" test "$v/kuznechik.zig" -ODebug -mcpu=native > "$v-selfhosted-Debug.log" 2>&1
 for cpu in znver4 znver5-gfni znver5-avx512vbmi znver5-avx2; do
  taskset -c 2 "$z" test "$v/kuznechik.zig" -OReleaseFast -mcpu="$cpu" -fllvm > "$v-$cpu.log" 2>&1
 done
 taskset -c 2 "$z" test "$v/kuznechik.zig" -OReleaseFast -target aarch64-linux-musl -fllvm --test-no-exec -femit-bin="$v-aarch64" > "$v-aarch64.log" 2>&1
 file "$v-aarch64" > "$v-aarch64-file.txt"
 sha256sum "$v-aarch64" >> binaries.sha256
 echo "validated $v"
done
