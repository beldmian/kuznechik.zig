#!/bin/bash
set -euo pipefail
cd /home/user/cbc-widths
zig=/home/user/zig-x86_64-linux-0.15.1/zig
mkdir -p evidence/attempts
mv evidence/validation/contracts.log evidence/attempts/contracts-branch-quota.log
for driver in contracts continuation; do
 cache="/home/user/.cache/cbc-validation-recovered/$driver"
 "$zig" test "$driver.zig" -mcpu=native -O ReleaseSafe --test-filter 'feedback' --cache-dir "$cache/local" --global-cache-dir "$cache/global" >"evidence/validation/$driver.log" 2>&1
done
printf 'ALL VALIDATION COMMANDS PASSED\n' > evidence/validation/validation-complete.txt
bash after.sh
python3 - <<'PY'
from pathlib import Path
import hashlib,json
manifest=json.loads(Path('source-sha256.json').read_text())
actual={n:hashlib.sha256(Path(n).read_bytes()).hexdigest() for n in manifest}
assert actual==manifest
Path('evidence/vm-source-sha256.json').write_text(json.dumps(actual,indent=2)+'\n')
PY
tar czf evidence.tar.gz evidence compiler.sha256 zig-version.txt lscpu.json uname.txt cache-filesystem-vm.txt runner.log
printf 'CBC_WORK_COMPLETE\n'
