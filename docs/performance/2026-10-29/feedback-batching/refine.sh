#!/bin/bash
set -euo pipefail
cd /home/user/kuz-feedback-next
mkdir -p inline-evidence
mv evidence/*.jsonl inline-evidence/
cp src/modes/classic.zig inline-classic.zig
mv src/modes/classic-next.zig src/modes/classic.zig
bash run.sh
bash run-tests.sh
