#!/bin/bash
set -euo pipefail
cd /home/user/kuz-feedback-next
zig=/tmp/zig-x86_64-linux-0.15.1/zig
stamp=$(date -u +%Y%m%dT%H%M%S)
mkdir -p baseline evidence
# v0.9.0 archive made from exact release commit, never the old VM working copy.
tar xzf baseline-v0.9.0.tar.gz -C baseline
variants=(baseline candidate)
if [ "$#" -gt 0 ]; then variants=("$@"); fi
for variant in "${variants[@]}"; do
  source=src/kuznechik.zig
  if [ "$variant" = baseline ]; then source=baseline/src/kuznechik.zig; fi
  for target in native baseline; do
    for mode in Debug ReleaseSafe ReleaseFast; do
      cache="/home/user/.cache/feedback-validation-$stamp/$variant-$target-$mode"
      mkdir -p "$cache"
      "$zig" test "$source" -mcpu="$target" -O "$mode" --cache-dir "$cache/local" --global-cache-dir "$cache/global" >"evidence/$variant-$target-$mode.log" 2>&1
      if [ "$target" = native ] && [ "$mode" = Debug ]; then
        "$zig" test "$source" -mcpu=native -O Debug -fllvm --cache-dir "$cache/llvm-local" --global-cache-dir "$cache/llvm-global" >"evidence/$variant-native-Debug-llvm.log" 2>&1
      fi
    done
  done
  cache="/home/user/.cache/feedback-validation-$stamp/$variant-aarch64"
  "$zig" test "$source" -target aarch64-linux-gnu -O ReleaseSafe --test-no-exec -femit-bin="$cache/test-aarch64" --cache-dir "$cache/local" --global-cache-dir "$cache/global" >"evidence/$variant-aarch64.log" 2>&1
  file "$cache/test-aarch64" >>"evidence/$variant-aarch64.log"
  sha256sum "$cache/test-aarch64" >>"evidence/$variant-aarch64.log"
done
cache="/home/user/.cache/feedback-validation-$stamp/contracts"
"$zig" test contracts.zig -mcpu=native -O ReleaseSafe --test-filter 'v0.9.0 feedback contexts' --cache-dir "$cache/local" --global-cache-dir "$cache/global" >evidence/contracts.log 2>&1
cache="/home/user/.cache/feedback-validation-$stamp/continuation"
"$zig" test continuation.zig -mcpu=native -O ReleaseSafe --test-filter 'feedback state continuation' --cache-dir "$cache/local" --global-cache-dir "$cache/global" >evidence/continuation.log 2>&1
printf '%s\n' 'ALL VALIDATION COMMANDS PASSED'  > evidence/validation-complete.txt
