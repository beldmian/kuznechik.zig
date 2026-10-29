#!/bin/bash
set -euo pipefail
set -x
cd /home/user/ocb/baseline
find src -type f -print0 | sort -z | xargs -0 sha256sum > ../logs/baseline-source-manifest.sha256
cd /home/user/ocb/source
Z=/home/user/zig-x86_64-linux-0.15.1/zig
# Full LLVM/link cross-compilation, in addition to run-vm.sh's semantic check.
"$Z" test src/kuznechik.zig -O ReleaseSafe -target aarch64-linux -mcpu=baseline --test-no-exec -femit-bin=/home/user/ocb/bin/tests-aarch64 --cache-dir /home/user/.cache/ocb/aarch64-linked-local --global-cache-dir /home/user/.cache/ocb/aarch64-linked-global > ../logs/aarch64-linked.log 2>&1
file ../bin/tests-aarch64 > ../logs/aarch64-binary.txt
sha256sum ../bin/* > ../logs/binary-manifest.sha256
find docs/performance/2026-10-29/ocb-schedule -type f -print0 | sort -z | xargs -0 sha256sum > ../logs/driver-manifest.sha256
for f in ../logs/disassembly*.log; do gzip -n "$f"; done
cd /home/user/ocb
tar -czf evidence.tar.gz logs
sha256sum evidence.tar.gz
