#!/bin/bash
set -euo pipefail
cd /home/user/medium-feedback
zig=/home/user/zig-x86_64-linux-0.15.1/zig
cp src/modes/classic_before_092.zig src/modes/classic_control_092.zig
sed 's,const After = kuz.modes.classic;,const After = @import("src/modes/classic_control_092.zig").Modes(kuz.Cipher);,' short-paired.zig > control-paired.zig
mkdir -p evidence/control
for target in native baseline; do
 "$zig" build-exe -O ReleaseFast -mcpu="$target" --cache-dir /home/user/.cache/medium-control-local --global-cache-dir /home/user/.cache/medium-control-global -Mroot=control-paired.zig -femit-bin="control-$target"
 taskset -c 0 "./control-$target" 271828 131072 99 0 2>"evidence/control/$target-forward1.jsonl"
done
