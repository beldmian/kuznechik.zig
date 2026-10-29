#!/bin/sh
set -eu
cd /home/user/kuz-gfni-pressure
export ZIG_LOCAL_CACHE_DIR=$(mktemp -d /home/user/.cache/gfni-pressure-pairs-local.XXXXXX)
export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d /home/user/.cache/gfni-pressure-pairs-global.XXXXXX)
printf '%s\n' "$ZIG_LOCAL_CACHE_DIR" "$ZIG_GLOBAL_CACHE_DIR" > pairs-caches.txt
z=/home/user/zig-x86_64-linux-0.15.1/zig
for v in "$@"; do
 cp algebra.zig "$v/algebra.zig"
 taskset -c 2 "$z" test "$v/algebra.zig" -OReleaseFast -mcpu=native -fllvm > "$v-algebra.log" 2>&1
 taskset -c 2 "$z" build-exe --dep baseline --dep candidate -OReleaseFast -mcpu=native -Mroot=pairs.zig -OReleaseFast -mcpu=native -Mbaseline=baseline/kuznechik.zig -OReleaseFast -mcpu=native -Mcandidate="$v/kuznechik.zig" -femit-bin="pairs-$v"
 sha256sum "pairs-$v" >> pairs-binaries.sha256
 echo "built $v"
done
