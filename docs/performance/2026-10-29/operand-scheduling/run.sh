#!/bin/sh
# Reproduce on an otherwise idle GFNI/VBMI Zen 5 host; requires Zig 0.15.1.
# Stage must be on disk, not /tmp tmpfs. No Git checkout is created or edited.
set -eu
receipt_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(git -C "$receipt_dir" rev-parse --show-toplevel)
stage_dir=${1:?Supply a fresh disk-backed stage directory}
z=${ZIG:-/tmp/zig-x86_64-linux-0.15.1/zig}
python3 "$receipt_dir/prepare.py" "$repo_dir" "$stage_dir"
python3 "$receipt_dir/variants.py" "$stage_dir"
python3 "$receipt_dir/prepare.py" "$repo_dir" "$stage_dir/variant69" 76,244,1,166 37
cp "$receipt_dir/../bitwise-normalization/pairs.zig" "$stage_dir/pairs.zig"
cd "$stage_dir"
export ZIG_LOCAL_CACHE_DIR=$(mktemp -d "$stage_dir/local-cache.XXXXXX")
export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d "$stage_dir/global-cache.XXXXXX")
printf '%s\n' "$ZIG_LOCAL_CACHE_DIR" "$ZIG_GLOBAL_CACHE_DIR" > caches.txt
for v in baseline candidate single first8 dfs-forward dfs-forward-r dfs-reverse dfs-reverse-r dfs-paired dfs-paired-r dfs-paired-reverse dfs-paired-reverse-r recursive-pqr recursive-prq recursive-qpr recursive-qrp recursive-rpq recursive-rqp variant69/candidate; do
 cp "$receipt_dir/../bitwise-normalization/codegen.zig" "$v/codegen.zig"
 name=$(printf '%s' "$v" | tr / -)
 taskset -c 2 "$z" build-obj "$v/codegen.zig" -OReleaseFast -mcpu=native -femit-bin="$name-codegen.o" -femit-asm="$name-codegen.s"
done
for v in candidate single recursive-prq recursive-qpr recursive-qrp recursive-rpq recursive-rqp variant69/candidate; do
 name=$(printf '%s' "$v" | tr / -)
 taskset -c 2 "$z" build-exe --dep baseline --dep candidate -OReleaseFast -mcpu=native -Mroot=pairs.zig -OReleaseFast -mcpu=native -Mbaseline=baseline/kuznechik.zig -OReleaseFast -mcpu=native -Mcandidate="$v/kuznechik.zig" -femit-bin="pairs-$name"
done
taskset -c 2 "$z" build-exe --dep baseline --dep candidate -OReleaseFast -mcpu=native -Mroot=pairs.zig -OReleaseFast -mcpu=native -Mbaseline=candidate/kuznechik.zig -OReleaseFast -mcpu=native -Mcandidate=baseline/kuznechik.zig -femit-bin=reverse
# No compiler or correctness suite may run alongside any of these timings.
taskset -c 0 ./pairs-single 85011 15 524288 1 16384 2> tied-85011.jsonl
taskset -c 0 ./pairs-candidate 85101 15 1048576 1 16384 2> first8-85101.jsonl
for v in recursive-prq recursive-qpr recursive-qrp recursive-rpq recursive-rqp; do
 taskset -c 0 "./pairs-$v" 85201 9 262144 25 16384 2> "$v-85201.jsonl"
done
taskset -c 0 ./pairs-variant69-candidate 85401 15 1048576 1 16384 2> tied69-85401.jsonl
taskset -c 0 ./pairs-candidate 85301 31 2097152 1 16384 2> final-85301.jsonl
taskset -c 0 ./pairs-candidate 85302 31 2097152 1 16384 2> final-85302.jsonl
taskset -c 0 ./reverse 85303 31 2097152 1 16384 2> reverse-final-85303.jsonl
for v in baseline candidate; do
 for opt in ReleaseFast ReleaseSafe Debug; do
  taskset -c 2 "$z" test "$v/kuznechik.zig" -O"$opt" -mcpu=native -fllvm > "$v-native-$opt.log" 2>&1
 done
done
for cpu in znver4 znver5-gfni znver5-avx512vbmi; do
 taskset -c 2 "$z" test candidate/kuznechik.zig -OReleaseFast -mcpu="$cpu" -fllvm > "candidate-$cpu.log" 2>&1
done
taskset -c 2 "$z" test candidate/kuznechik.zig -OReleaseFast -target aarch64-linux-musl -fllvm -fno-emit-bin > candidate-aarch64.log 2>&1
python3 "$receipt_dir/codegen.py" "$stage_dir" > codegen.json
python3 "$receipt_dir/summarize.py" "$stage_dir"
lscpu -J > lscpu.json
uname -a > uname.txt
sha256sum "$z" pairs-* reverse > binary.sha256
