#!/bin/sh
set -eu
cd /home/user/kuz-gfni-spills
export ZIG_LOCAL_CACHE_DIR=$(mktemp -d /home/user/.cache/kuz-validate-local.XXXXXX)
export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d /home/user/.cache/kuz-validate-global.XXXXXX)
printf '%s\n' "$ZIG_LOCAL_CACHE_DIR" "$ZIG_GLOBAL_CACHE_DIR" > validation-caches.txt
z=/tmp/zig-x86_64-linux-0.15.1/zig
for v in final tied69; do
 taskset -c 2 "$z" build-obj "$v/codegen.zig" -OReleaseFast -mcpu=native -femit-bin="$v-codegen.o" -femit-asm="$v-codegen.s"
 taskset -c 2 "$z" build-exe --dep baseline --dep candidate -OReleaseFast -mcpu=native -Mroot=pairs.zig -OReleaseFast -mcpu=native -Mbaseline=baseline/kuznechik.zig -OReleaseFast -mcpu=native -Mcandidate="$v/kuznechik.zig" -femit-bin="pairs-$v"
done
taskset -c 2 "$z" build-exe --dep baseline --dep candidate -OReleaseFast -mcpu=native -Mroot=pairs.zig -OReleaseFast -mcpu=native -Mbaseline=final/kuznechik.zig -OReleaseFast -mcpu=native -Mcandidate=baseline/kuznechik.zig -femit-bin=reverse-final
for v in baseline final; do
 for opt in ReleaseFast ReleaseSafe Debug; do
  taskset -c 2 "$z" test "$v/kuznechik.zig" -O"$opt" -mcpu=native -fllvm > "$v-native-$opt.log" 2>&1
 done
done
for cpu in znver4 znver5-gfni znver5-avx512vbmi; do
 taskset -c 2 "$z" test final/kuznechik.zig -OReleaseFast -mcpu="$cpu" -fllvm > "final-$cpu.log" 2>&1
done
taskset -c 2 "$z" test final/kuznechik.zig -OReleaseFast -target aarch64-linux-musl -fllvm -fno-emit-bin > final-aarch64.log 2>&1
lscpu -J > lscpu.json
uname -a > uname.txt
sha256sum "$z" pairs-final reverse-final pairs-tied69 > final-binary.sha256
