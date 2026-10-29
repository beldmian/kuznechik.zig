#!/bin/sh
# Reproduce on an idle GFNI-capable Zen5 host. All compiler caches are on disk.
set -eu
receipt_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(git -C "$receipt_dir" rev-parse --show-toplevel)
stage_dir=${1:-$HOME/.cache/kuz-bitwise-reproduce}
compiler=${ZIG:-/tmp/zig-x86_64-linux-0.15.1/zig}
python3 "$receipt_dir/prepare.py" "$repo_dir" "$stage_dir"
python3 "$receipt_dir/prepare.py" "$repo_dir" "$stage_dir/variant69" 76,244,1,166 37
cp "$receipt_dir/pairs.zig" "$stage_dir/pairs.zig"
cd "$stage_dir"
# Use fresh caches, rather than a preexisting shared compiler cache.
export ZIG_LOCAL_CACHE_DIR=$(mktemp -d "$stage_dir/local-cache.XXXXXX")
export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d "$stage_dir/global-cache.XXXXXX")
for variant in candidate variant69/candidate; do
    if [ "$variant" = candidate ]; then name=70; else name=69; fi
    taskset -c 2 "$compiler" build-exe --dep baseline --dep candidate -OReleaseFast -mcpu=native -Mroot=pairs.zig -OReleaseFast -mcpu=native -Mbaseline=baseline/kuznechik.zig -OReleaseFast -mcpu=native -Mcandidate="$variant/kuznechik.zig" -femit-bin="pairs$name"
done
taskset -c 2 "$compiler" build-exe --dep baseline --dep candidate -OReleaseFast -mcpu=native -Mroot=pairs.zig -OReleaseFast -mcpu=native -Mbaseline=candidate/kuznechik.zig -OReleaseFast -mcpu=native -Mcandidate=baseline/kuznechik.zig -femit-bin=reverse70
for variant in baseline candidate variant69/candidate; do
    cp "$receipt_dir/codegen.zig" "$variant/codegen.zig"
    name=$(printf '%s' "$variant" | tr / -)
    taskset -c 2 "$compiler" build-obj "$variant/codegen.zig" -OReleaseFast -mcpu=native -femit-bin="$name-codegen.o" -femit-asm="$name-codegen.s"
done
# No compiler or correctness suite runs alongside these timings.
taskset -c 0 ./pairs70 70001 15 524288 25 16384 2> pair70-70001.jsonl
taskset -c 0 ./pairs69 69001 15 524288 25 16384 2> pair69-69001.jsonl
taskset -c 0 ./pairs70 70002 31 2097152 1 16384 2> pair70-70002.jsonl
taskset -c 0 ./reverse70 70003 31 2097152 1 16384 2> reverse70-70003.jsonl
for variant in baseline candidate; do
    for opt in ReleaseFast ReleaseSafe Debug; do
        taskset -c 2 "$compiler" test "$variant/kuznechik.zig" -O"$opt" -mcpu=native -fllvm > "$variant-native-$opt.log" 2>&1
    done
done
lscpu -J > lscpu.json
uname -a > uname.txt
sha256sum "$compiler" > compiler.sha256
for cpu in znver4 znver5-gfni znver5-avx512vbmi; do
    taskset -c 2 "$compiler" test candidate/kuznechik.zig -OReleaseFast -mcpu="$cpu" -fllvm > "candidate-$cpu.log" 2>&1
done
taskset -c 2 "$compiler" test candidate/kuznechik.zig -OReleaseFast -target aarch64-linux-musl -fllvm -fno-emit-bin > candidate-aarch64.log 2>&1
