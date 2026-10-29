#!/bin/bash
set -euo pipefail
cd /home/user/kuz-feedback-next
mkdir -p noinline-all-widths-evidence
mv evidence/*.jsonl evidence/*.log noinline-all-widths-evidence/
if [ -f evidence/validation-complete.txt ]; then mv evidence/validation-complete.txt noinline-all-widths-evidence/; fi
cp noinline-all-widths-evidence/baseline-*.log evidence/
cp src/modes/classic.zig noinline-all-widths-classic.zig
mv src/modes/classic-final.zig src/modes/classic.zig
cache="/home/user/.cache/feedback-baseline-debug-llvm-$(date -u +%Y%m%dT%H%M%S)"
/tmp/zig-x86_64-linux-0.15.1/zig test baseline/src/kuznechik.zig -mcpu=native -O Debug -fllvm --cache-dir "$cache/local" --global-cache-dir "$cache/global" >evidence/baseline-native-Debug-llvm.log 2>&1
cache="/home/user/.cache/feedback-baseline-aarch64-$(date -u +%Y%m%dT%H%M%S)"
/tmp/zig-x86_64-linux-0.15.1/zig test baseline/src/kuznechik.zig -target aarch64-linux-gnu -O ReleaseSafe --test-no-exec -femit-bin="$cache/test-aarch64" --cache-dir "$cache/local" --global-cache-dir "$cache/global" >evidence/baseline-aarch64.log 2>&1
file "$cache/test-aarch64" >>evidence/baseline-aarch64.log
sha256sum "$cache/test-aarch64" >>evidence/baseline-aarch64.log
bash run.sh
bash run-tests.sh candidate
