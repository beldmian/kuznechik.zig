#!/bin/sh
set -eu
cd /home/user/kuz-gfni-pressure
export ZIG_LOCAL_CACHE_DIR=$(mktemp -d /home/user/.cache/gfni-pressure-confirm-local.XXXXXX)
export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d /home/user/.cache/gfni-pressure-confirm-global.XXXXXX)
printf '%s\n' "$ZIG_LOCAL_CACHE_DIR" "$ZIG_GLOBAL_CACHE_DIR" > confirm-caches.txt
z=/home/user/zig-x86_64-linux-0.15.1/zig
for v in ready00 ready12; do
 taskset -c 2 "$z" build-exe --dep baseline --dep candidate -OReleaseFast -mcpu=native -Mroot=pairs.zig -OReleaseFast -mcpu=native -Mbaseline="$v/kuznechik.zig" -OReleaseFast -mcpu=native -Mcandidate=baseline/kuznechik.zig -femit-bin="reverse-$v"
done
for v in candidate ready00 ready12; do
 taskset -c 2 "$z" build-exe --dep baseline --dep candidate -OReleaseFast -mcpu=baseline -Mroot=pairs.zig -OReleaseFast -mcpu=baseline -Mbaseline=baseline/kuznechik.zig -OReleaseFast -mcpu=baseline -Mcandidate="$v/kuznechik.zig" -femit-bin="portable-$v"
done
sha256sum pairs-* reverse-ready* portable-* > confirm-binaries.sha256
for v in candidate ready00 ready12; do
 for seed in 902902 902903; do
  taskset -c 0 ./pairs-"$v" "$seed" 31 1048576 > "confirm-$v-$seed.jsonl" 2>&1
 done
 echo "confirmed forward $v"
done
for v in ready00 ready12; do
 taskset -c 0 ./reverse-"$v" 902904 31 1048576 > "reverse-$v-902904.jsonl" 2>&1
 echo "confirmed reverse $v"
done
for v in candidate ready00 ready12; do
 taskset -c 0 ./portable-"$v" 902905 15 131072 > "portable-$v-902905.jsonl" 2>&1
 echo "timed portable $v"
done
