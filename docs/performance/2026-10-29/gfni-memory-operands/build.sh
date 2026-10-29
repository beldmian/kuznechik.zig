#!/bin/sh
set -eu
cd /home/user/kuz-gfni-memory
export ZIG_LOCAL_CACHE_DIR=$(mktemp -d /home/user/.cache/gfni-memory-build-local.XXXXXX)
export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d /home/user/.cache/gfni-memory-build-global.XXXXXX)
printf '%s\n' "$ZIG_LOCAL_CACHE_DIR" "$ZIG_GLOBAL_CACHE_DIR" > build-caches.txt
z=/home/user/zig-x86_64-linux-0.15.1/zig
for v in baseline explicit-clobber explicit-read; do
 taskset -c 2 "$z" test "$v/products.zig" -OReleaseFast -mcpu=native -fllvm > "$v-products.log" 2>&1
 taskset -c 2 "$z" test "$v/algebra.zig" -OReleaseFast -mcpu=native -fllvm > "$v-algebra.log" 2>&1
 taskset -c 2 "$z" build-obj "$v/codegen.zig" -OReleaseFast -mcpu=native -femit-asm="$v-codegen.s" -femit-llvm-ir="$v-codegen.ll" -femit-bin="$v-codegen.o"
 echo "built codegen and algebra $v"
done
for v in candidate explicit-clobber explicit-read; do
 for placement in forward reverse portable; do
  a=baseline; b=$v; cpu=native
  if [ "$placement" = reverse ]; then a=$v; b=baseline; fi
  if [ "$placement" = portable ]; then cpu=baseline; fi
  taskset -c 2 "$z" build-exe --dep baseline --dep candidate -OReleaseFast -mcpu="$cpu" -Mroot=pairs.zig -OReleaseFast -mcpu="$cpu" -Mbaseline="$a/kuznechik.zig" -OReleaseFast -mcpu="$cpu" -Mcandidate="$b/kuznechik.zig" -femit-bin="pairs-$v-$placement"
  sha256sum "pairs-$v-$placement" >> binaries.sha256
  objdump -d -Mintel "pairs-$v-$placement" | gzip -9 > "pairs-$v-$placement.objdump.gz"
 done
 echo "built pairs $v"
done
python3 codegen.py . > codegen-table.txt
