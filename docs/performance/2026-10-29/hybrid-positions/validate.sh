#!/bin/bash
set -euo pipefail
z=${ZIG:-/home/user/hybrid-positions/toolchain/zig}
cache_root=${CACHE_ROOT:-/home/user/.cache/hybrid-positions}
mkdir -p "$cache_root"
export ZIG_LOCAL_CACHE_DIR=$(mktemp -d "$cache_root"/test-local.XXXXXX)
export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d "$cache_root"/test-global.XXXXXX)
printf '%s\n' "$ZIG_LOCAL_CACHE_DIR" "$ZIG_GLOBAL_CACHE_DIR" > test-caches.txt
for v in "$@"; do
 for opt in Debug ReleaseSafe ReleaseFast; do
  taskset -c 2 "$z" test "$v/kuznechik.zig" -O"$opt" -mcpu=native -fllvm > "$v-native-$opt.log" 2>&1
 done
 taskset -c 2 "$z" test "$v/correctness.zig" -OReleaseFast -mcpu=native -fllvm > "$v-basis-native-ReleaseFast.log" 2>&1
 taskset -c 2 "$z" test "$v/kuznechik.zig" -ODebug -mcpu=native -fno-llvm > "$v-selfhosted-Debug.log" 2>&1
 for cpu in znver4 znver5-gfni znver5-avx512vbmi znver5-avx512vl; do
  taskset -c 2 "$z" test "$v/kuznechik.zig" -OReleaseFast -mcpu="$cpu" -fllvm > "$v-$cpu.log" 2>&1
 done
done
