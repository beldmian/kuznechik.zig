#!/bin/sh
set -eu
receipt_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(git -C "$receipt_dir" rev-parse --show-toplevel)
stage_dir=${1:-/tmp/kuz-ccm-full-block}
compiler=${ZIG:-/tmp/zig-x86_64-linux-0.15.1/zig}
python3 "$receipt_dir/prepare.py" "$repo_dir" "$stage_dir"
cp "$receipt_dir/pairs.zig" "$stage_dir/pairs.zig"
cd "$stage_dir"
for target_cpu in native x86_64; do
    "$compiler" build-exe --dep cipher --dep new -OReleaseFast -mcpu="$target_cpu" -Mroot=pairs.zig -OReleaseFast -mcpu="$target_cpu" -Mcipher=baseline/kuznechik.zig -OReleaseFast -mcpu="$target_cpu" -Mnew=candidate-tree/kuznechik.zig -femit-bin="$target_cpu-pairs"
    for seed in 7654321 99887766; do
        taskset -c 0 "./$target_cpu-pairs" "$seed" 2> "$target_cpu-$seed.jsonl"
    done
done
"$compiler" build-exe --dep cipher --dep new -OReleaseFast -mcpu=native -Mroot=pairs.zig -OReleaseFast -mcpu=native -Mcipher=candidate-tree/kuznechik.zig -OReleaseFast -mcpu=native -Mnew=baseline/kuznechik.zig -femit-bin=reverse-pairs
taskset -c 0 ./reverse-pairs 44332211 2> reverse-44332211.jsonl
for mode in Debug ReleaseSafe ReleaseFast; do
    taskset -c 0 "$compiler" test candidate-tree/kuznechik.zig -fllvm -O "$mode" -mcpu=native > "candidate-native-$mode.log" 2>&1
done
cp "$receipt_dir/alignment.zig" alignment.zig
for mode in Debug ReleaseSafe ReleaseFast; do
    taskset -c 0 "$compiler" test --dep baseline --dep candidate -fllvm -O "$mode" -mcpu=native -Mroot=alignment.zig -O "$mode" -mcpu=native -Mbaseline=baseline/kuznechik.zig -O "$mode" -mcpu=native -Mcandidate=candidate-tree/kuznechik.zig > "alignment-native-$mode.log" 2>&1
done
taskset -c 0 "$compiler" test --dep baseline --dep candidate -OReleaseFast -mcpu=x86_64 -Mroot=alignment.zig -OReleaseFast -mcpu=x86_64 -Mbaseline=baseline/kuznechik.zig -OReleaseFast -mcpu=x86_64 -Mcandidate=candidate-tree/kuznechik.zig > alignment-portable.log 2>&1
