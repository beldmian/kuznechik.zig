#!/bin/bash
set -euo pipefail
cd /home/user/gfni-pair
mkdir -p evidence
cp validation-audit.jsonl evidence/initial-validation-audit.jsonl
cp retained-validation-audit.jsonl evidence/matrix-validation-audit.jsonl
find baseline candidate narrow control initial-candidate inside switch wide wide-switch -name '*.zig' -print0 | sort -z | xargs -0 sha256sum > evidence/source.sha256
find . -maxdepth 1 -type f -name 'bin-*' -print0 | sort -z | xargs -0 sha256sum > evidence/binaries.sha256
sha256sum test-aarch64 >>evidence/binaries.sha256
df -T /home/user/.cache >evidence/cache-filesystem.txt
# Only source, assembly, logs and small metadata: no checkout, VM credentials,
# Zig archive, executables or caches.
tar czf /home/user/gfni-pair-evidence.tar.gz baseline candidate narrow control initial-candidate inside switch wide wide-switch initial-asm initial-validation logs final retained controls validation evidence *.zig *.s run.sh final.sh retained.sh validate.sh audit.py controls.sh wide-switch-run.sh fixed-run.sh
sha256sum /home/user/gfni-pair-evidence.tar.gz > /home/user/gfni-pair-evidence.sha256
