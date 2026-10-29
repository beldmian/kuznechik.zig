#!/bin/bash
set -euo pipefail
z=${ZIG:-/home/user/hybrid-positions/toolchain/zig}
cache_root=${CACHE_ROOT:-/home/user/.cache/hybrid-positions}
export ZIG_LOCAL_CACHE_DIR=$(mktemp -d "$cache_root"/confirm-local.XXXXXX)
export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d "$cache_root"/confirm-global.XXXXXX)
printf '%s\n' "$ZIG_LOCAL_CACHE_DIR" "$ZIG_GLOBAL_CACHE_DIR" > confirm-caches.txt
for v in boundary spaced split2; do
 taskset -c 2 "$z" build-exe --dep baseline --dep candidate -OReleaseFast -mcpu=native -Mroot=pairs.zig -OReleaseFast -mcpu=native -Mbaseline="$v/kuznechik.zig" -OReleaseFast -mcpu=native -Mcandidate=baseline/kuznechik.zig -femit-bin="reverse-$v"
 taskset -c 2 "$z" build-exe --dep baseline --dep candidate -OReleaseFast -mcpu=x86_64 -Mroot=pairs.zig -OReleaseFast -mcpu=x86_64 -Mbaseline=baseline/kuznechik.zig -OReleaseFast -mcpu=x86_64 -Mcandidate="$v/kuznechik.zig" -femit-bin="portable-$v"
done
taskset -c 2 "$z" build-exe --dep baseline --dep candidate -OReleaseFast -mcpu=x86_64 -Mroot=pairs.zig -OReleaseFast -mcpu=x86_64 -Mbaseline=baseline/kuznechik.zig -OReleaseFast -mcpu=x86_64 -Mcandidate=control/kuznechik.zig -femit-bin=portable-control
sha256sum "$z" reverse-* portable-* > confirm-binaries.sha256
# No compilers/tests during these alternating paired timings.
for seed in 94201 94202; do
 taskset -c 0 ./pairs-control "$seed" 31 524288 0 16384 2> "confirm-control-$seed.jsonl"
 for v in boundary spaced split2; do
  taskset -c 0 "./pairs-$v" "$seed" 31 524288 0 16384 2> "confirm-$v-$seed.jsonl"
 done
done
for v in boundary spaced split2; do
 taskset -c 0 "./reverse-$v" 94203 31 524288 0 16384 2> "reverse-$v-94203.jsonl"
 taskset -c 0 "./portable-$v" 94204 15 131072 0 16384 2> "portable-$v-94204.jsonl"
done
taskset -c 0 ./portable-control 94204 15 131072 0 16384 2> portable-control-94204.jsonl
