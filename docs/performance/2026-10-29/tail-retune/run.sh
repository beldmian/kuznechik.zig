#!/bin/sh
# Run only on an otherwise idle GFNI-capable Zen5 target, with CPU0 available.
set -eu
receipt_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(git -C "$receipt_dir" rev-parse --show-toplevel)
stage_dir=${1:-/tmp/kuz-tail-retune}
compiler=${ZIG:-/tmp/zig-x86_64-linux-0.15.1/zig}
python3 "$receipt_dir/prepare.py" "$repo_dir" "$stage_dir"
cp "$receipt_dir/pairs.zig" "$stage_dir/pairs.zig"
cd "$stage_dir"
for variant in opposite candidate; do
    "$compiler" build-exe --dep baseline --dep candidate -OReleaseFast -mcpu=native -Mroot=pairs.zig -OReleaseFast -mcpu=native -Mbaseline=baseline/kuznechik.zig -OReleaseFast -mcpu=native -Mcandidate="$variant/kuznechik.zig" -femit-bin="$variant-pairs"
done
for seed in 424242 987654321; do
    taskset -c 0 ./opposite-pairs "$seed" 15 20000 2> "sweep-$seed.jsonl"
done
for seed in 271828 314159; do
    taskset -c 0 ./candidate-pairs "$seed" 31 60000 17 25 2> "narrow-$seed.jsonl"
done
taskset -c 0 ./candidate-pairs 1618033 15 20000 2> narrow-1618033.jsonl
"$compiler" build-exe --dep baseline --dep candidate -OReleaseFast -mcpu=native -Mroot=pairs.zig -OReleaseFast -mcpu=native -Mbaseline=candidate/kuznechik.zig -OReleaseFast -mcpu=native -Mcandidate=baseline/kuznechik.zig -femit-bin=reverse
# The reverse ratio is released/candidate; a number above1 favors the candidate.
taskset -c 0 ./reverse 818181 31 60000 17 25 2> reverse-818181.jsonl
lscpu -J > lscpu.json
uname -a > uname.txt
sha256sum "$compiler" > compiler.sha256
for variant in one-matrix one-toeplitz; do
    "$compiler" build-exe --dep baseline --dep candidate -OReleaseFast -mcpu=native -Mroot=pairs.zig -OReleaseFast -mcpu=native -Mbaseline=baseline/kuznechik.zig -OReleaseFast -mcpu=native -Mcandidate="$variant/kuznechik.zig" -femit-bin="$variant-pairs"
    taskset -c 0 "./$variant-pairs" 112358 31 60000 1 1 2> "$variant-112358.jsonl"
done
taskset -c 0 ./candidate-pairs 2236067 15 40000 2> narrow-2236067.jsonl
"$compiler" build-exe --dep baseline --dep candidate -OReleaseFast -mcpu=native -Mroot=pairs.zig -OReleaseFast -mcpu=native -Mbaseline=baseline/kuznechik.zig -OReleaseFast -mcpu=native -Mcandidate=matrix64/kuznechik.zig -femit-bin=matrix64-pairs
taskset -c 0 ./matrix64-pairs 998244353 15 20000 61 63 2> matrix64-998244353.jsonl
