#!/bin/bash
set -euo pipefail
cd /home/user/cbc-widths
zig=/home/user/zig-x86_64-linux-0.15.1/zig
stamp=$(date -u +%Y%m%dT%H%M%S)
mkdir -p baseline evidence/validation
out=evidence/validation
tar xzf baseline-v0.9.3.tar.gz -C baseline
for variant in baseline candidate; do
 source=src/kuznechik.zig
 if [ "$variant" = baseline ]; then source=baseline/src/kuznechik.zig; fi
 for target in native baseline; do
  modes=(ReleaseFast)
  if [ "$variant" = candidate ]; then modes=(Debug ReleaseSafe ReleaseFast); fi
  for mode in "${modes[@]}"; do
   cache="/home/user/.cache/cbc-validation-$stamp/$variant-$target-$mode"
   mkdir -p "$cache"
   taskset -c 0 "$zig" test "$source" -mcpu="$target" -O "$mode" --cache-dir "$cache/local" --global-cache-dir "$cache/global" >"$out/$variant-$target-$mode.log" 2>&1
   if [ "$variant" = candidate ] && [ "$target" = native ] && [ "$mode" = Debug ]; then
    taskset -c 0 "$zig" test "$source" -mcpu=native -O Debug -fllvm --cache-dir "$cache/llvm-local" --global-cache-dir "$cache/llvm-global" >"$out/$variant-native-Debug-llvm.log" 2>&1
   fi
  done
 done
done
for cpu in znver5-gfni znver5-avx512vbmi znver5-avx2; do
 cache="/home/user/.cache/cbc-validation-$stamp/gate-$cpu"
 taskset -c 0 "$zig" test src/kuznechik.zig -mcpu="$cpu" -O ReleaseFast -fllvm --cache-dir "$cache/local" --global-cache-dir "$cache/global" >"$out/gate-$cpu.log" 2>&1
done
cache="/home/user/.cache/cbc-validation-$stamp/cross"
mkdir -p "$cache"
"$zig" test src/kuznechik.zig -target aarch64-linux-gnu -O ReleaseSafe --test-no-exec -femit-bin="$cache/test-aarch64" --cache-dir "$cache/local" --global-cache-dir "$cache/global" >"$out/candidate-aarch64.log" 2>&1
file "$cache/test-aarch64" >>"$out/candidate-aarch64.log"
sha256sum "$cache/test-aarch64" >>"$out/candidate-aarch64.log"
for driver in contracts continuation; do
 cache="/home/user/.cache/cbc-validation-$stamp/$driver"
 "$zig" test "$driver.zig" -mcpu=native -O ReleaseSafe --test-filter 'feedback' --cache-dir "$cache/local" --global-cache-dir "$cache/global" >"$out/$driver.log" 2>&1
done
printf '%s\n' 'ALL VALIDATION COMMANDS PASSED' > "$out/validation-complete.txt"
