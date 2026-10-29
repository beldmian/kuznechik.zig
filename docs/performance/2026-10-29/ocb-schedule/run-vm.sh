#!/bin/bash
set -euo pipefail
set -x
cd /home/user/ocb
mkdir -p source baseline logs bin
 tar -xzf source2.tar.gz -C source
 tar -xzf baseline.tar.gz -C baseline
Z=/home/user/zig-x86_64-linux-0.15.1/zig
D=docs/performance/2026-10-29/ocb-schedule
cd source
find src -type f -print0 | sort -z | xargs -0 sha256sum > ../logs/source-manifest.sha256
for target in native x86_64; do
  for layout in forward reverse control; do
    first=$D/snapshots/baseline/ocb.zig
    second=$D/snapshots/candidate/ocb.zig
    if [ "$layout" = reverse ]; then first=$D/snapshots/candidate/ocb.zig; second=$D/snapshots/baseline/ocb.zig; fi
    if [ "$layout" = control ]; then second=$D/snapshots/control/ocb.zig; fi
    label=bench-$target-$layout
    "$Z" build-exe -O ReleaseFast -mcpu="$target" --cache-dir /home/user/.cache/ocb/$label-local --global-cache-dir /home/user/.cache/ocb/$label-global --dep kuz --dep first --dep second -Mroot=$D/bench.zig -Mkuz=src/kuznechik.zig -Mfirst=$first -Msecond=$second -femit-bin=../bin/$label > ../logs/build-$label.log 2>&1
    nm -n ../bin/$label > ../logs/symbols-$label.log
    objdump -d ../bin/$label > ../logs/disassembly-$label.log
  done
done
# Keep compilation and all correctness tests outside benchmark time.
for tree in baseline source; do
  cd /home/user/ocb/$tree
  if [ "$tree" = baseline ]; then modes=ReleaseSafe; else modes='Debug ReleaseSafe ReleaseFast'; fi
  for target in native x86_64; do
    for mode in $modes; do
      label=$tree-$target-$mode
      taskset -c 0 "$Z" test src/kuznechik.zig -O "$mode" -mcpu="$target" --cache-dir /home/user/.cache/ocb/$label-local --global-cache-dir /home/user/.cache/ocb/$label-global > /home/user/ocb/logs/test-$label.log 2>&1
    done
  done
done
cd /home/user/ocb/source
"$Z" test src/kuznechik.zig -O ReleaseSafe -target aarch64-linux -mcpu=baseline -fno-emit-bin --cache-dir /home/user/.cache/ocb/aarch64-local --global-cache-dir /home/user/.cache/ocb/aarch64-global > ../logs/aarch64.log 2>&1
# Each invocation contains its own warmup, seven alternating timed pairs,
# complete pool validation after each sample, and checksums.
for seed in 7253 9189 20261029; do
  for target in native x86_64; do
    for layout in forward reverse control; do
      taskset -c 0 ../bin/bench-$target-$layout "$seed" > ../logs/bench-$target-$layout-$seed.csv 2>&1
    done
  done
done
