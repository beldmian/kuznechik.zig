#!/usr/bin/env python3
from pathlib import Path
import tarfile,hashlib,json
p=Path(__file__).resolve().parent
out=Path('/home/t3/.cache/kuz-cbc-widths')
out.mkdir(parents=True,exist_ok=True)
with tarfile.open(p/'baseline-v0.9.3.tar.gz') as t:t.extractall(out,filter='data')
(out/'src/modes/classic_before_093.zig').write_bytes((out/'src/modes/classic.zig').read_bytes())
(out/'src/modes/classic.zig').write_bytes(Path('src/modes/classic.zig').read_bytes())
(out/'src/modes/classic_control_093.zig').write_bytes((out/'src/modes/classic_before_093.zig').read_bytes())
for name in ['paired.zig','after.sh','codegen.zig','contracts.zig','continuation.zig','run.sh','run-tests.sh','baseline-v0.9.3.tar.gz']:
 (out/name).write_bytes((p/name).read_bytes())
s=(out/'paired.zig').read_text()
s=s.replace('const Before = @import("src/modes/classic_before_093.zig").Modes(kuz.Cipher);\nconst After = kuz.modes.classic;', 'const Before = kuz.modes.classic;\nconst After = @import("src/modes/classic_before_093.zig").Modes(kuz.Cipher);')
(out/'paired-reversed.zig').write_text(s)
s=(out/'paired.zig').read_text().replace('const After = kuz.modes.classic;', 'const After = @import("src/modes/classic_control_093.zig").Modes(kuz.Cipher);')
(out/'paired-control.zig').write_text(s)
manifest={str(f.relative_to(out)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(out.rglob('*')) if f.is_file() and '.zig-cache' not in str(f)}
(p/'source-sha256.json').write_text(json.dumps(manifest,indent=2)+'\n')
with tarfile.open(p/'candidate-source.tar.gz','w:gz') as t:
 for name in manifest:t.add(out/name,arcname=name)
print(out)
