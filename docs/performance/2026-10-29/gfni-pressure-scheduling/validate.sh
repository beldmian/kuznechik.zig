#!/bin/sh
set -eu
cd /home/user/kuz-gfni-pressure
export ZIG_LOCAL_CACHE_DIR=$(mktemp -d /home/user/.cache/gfni-pressure-validate-local.XXXXXX)
export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d /home/user/.cache/gfni-pressure-validate-global.XXXXXX)
printf '%s\n' "$ZIG_LOCAL_CACHE_DIR" "$ZIG_GLOBAL_CACHE_DIR" > validation-caches.txt
z=/home/user/zig-x86_64-linux-0.15.1/zig
for v in baseline ready00 ready12 ready18 ready19; do
 taskset -c 2 "$z" test "$v/kuznechik.zig" -OReleaseFast -mcpu=native -fllvm > "$v-native-ReleaseFast.log" 2>&1
 echo "validated $v Fast"
done
for v in baseline ready00; do
 for opt in Debug ReleaseSafe; do
  taskset -c 2 "$z" test "$v/kuznechik.zig" -O"$opt" -mcpu=native -fllvm > "$v-native-$opt.log" 2>&1
 done
 taskset -c 2 "$z" test "$v/kuznechik.zig" -ODebug -mcpu=native > "$v-selfhosted-Debug.log" 2>&1
 for cpu in znver4 znver5-gfni znver5-avx512vbmi znver5-avx2; do
  taskset -c 2 "$z" test "$v/kuznechik.zig" -OReleaseFast -mcpu="$cpu" -fllvm > "$v-$cpu.log" 2>&1
 done
 echo "validated $v other profiles"
done
