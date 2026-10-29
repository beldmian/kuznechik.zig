#!/bin/bash
set -euo pipefail
cd /home/user/medium-feedback
zig=/home/user/zig-x86_64-linux-0.15.1/zig
mkdir -p evidence/assembly
# These run only AFTER all validation commands have exited.
for target in native baseline; do
 taskset -c 0 "./control-$target" 314159 131072 99 3 2>"evidence/control/$target-forward2.jsonl"
 taskset -c 0 "./control-$target" 1618033 131072 99 1 2>"evidence/control/$target-forward3.jsonl"
done
# Confirm the unchanged-width controls with two additional seeds/placements.
for target in native baseline; do
 taskset -c 0 "./excluded-$target-forward" 424242 131072 99 0 2>"evidence/excluded/$target-forward3.jsonl"
 taskset -c 0 "./excluded-$target-reverse" 8675309 131072 99 3 2>"evidence/excluded/$target-reverse2.jsonl"
done
cp src/modes/classic.zig final-classic.zig
for variant in final threshold-measured threshold-noinline-scalar; do
 if [ "$variant" = final ]; then cp final-classic.zig src/modes/classic.zig; else cp "variants/$variant.zig" src/modes/classic.zig; fi
 for target in native baseline; do
  "$zig" build-obj codegen.zig -O ReleaseFast -mcpu="$target" --cache-dir /home/user/.cache/medium-asm-local --global-cache-dir /home/user/.cache/medium-asm-global -femit-bin="evidence/assembly/$variant-$target.o" -femit-asm="evidence/assembly/$variant-$target.s"
  nm -S --size-sort "evidence/assembly/$variant-$target.o" >"evidence/assembly/$variant-$target.nm"
 done
done
cp final-classic.zig src/modes/classic.zig
python3 - <<'PY'
import pathlib,hashlib,json
p=pathlib.Path('.')
manifest={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(list(p.glob('src/**/*.zig')) + list(p.glob('*.zig')))}
pathlib.Path('evidence/vm-source-sha256.json').write_text(json.dumps(manifest,indent=2)+'\n')
PY
lscpu -J > evidence/lscpu.json
uname -a > evidence/uname.txt
"$zig" version > evidence/zig-version.txt
sha256sum "$zig" > evidence/compiler-executable.sha256
printf '%s\n' 'POST-VALIDATION CONTROLS CODEGEN AND SOURCE HASHES COMPLETE' > evidence/post-validation-complete.txt
