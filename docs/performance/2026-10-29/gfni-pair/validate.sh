#!/bin/bash
set -euo pipefail
cd /home/user/gfni-pair
Z=/home/user/zig-x86_64-linux-0.15.1/zig
stamp=$(date -u +%Y%m%dT%H%M%S)
mkdir -p validation
run_test() {
 local name=$1 source=$2 cpu=$3 mode=$4 backend=$5
 local cache=/home/user/.cache/gfni-pair-validation-$stamp/$name
 "$Z" test "$source" -mcpu="$cpu" -O "$mode" "$backend" --cache-dir "$cache/local" --global-cache-dir "$cache/global" > "validation/$name.log" 2>&1
 python3 audit.py "validation/$name.log"
}
run_test baseline-native baseline/src/kuznechik.zig native ReleaseFast -fllvm
for mode in Debug ReleaseSafe ReleaseFast; do
 run_test candidate-native-$mode candidate/src/kuznechik.zig native "$mode" -fllvm
 run_test candidate-portable-$mode candidate/src/kuznechik.zig baseline "$mode" -fllvm
done
run_test candidate-selfhost candidate/src/kuznechik.zig native Debug -fno-llvm
for cpu in znver5-avx512vl znver5-avx2 znver5-gfni znver5-avx512vbmi; do
 run_test gate-$cpu candidate/src/kuznechik.zig "$cpu" ReleaseFast -fllvm
done
run_test narrow-native narrow/src/kuznechik.zig native ReleaseFast -fllvm
cache=/home/user/.cache/gfni-pair-validation-$stamp/cross
"$Z" test candidate/src/kuznechik.zig -target aarch64-linux-gnu -O ReleaseSafe -fllvm --test-no-exec -femit-bin=test-aarch64 --cache-dir "$cache/local" --global-cache-dir "$cache/global" >validation/aarch64.log 2>&1
file test-aarch64 >>validation/aarch64.log
sha256sum test-aarch64 >>validation/aarch64.log
printf 'Completed all commands\n' >validation/completed.txt
