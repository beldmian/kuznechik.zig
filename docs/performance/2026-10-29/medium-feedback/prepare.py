#!/usr/bin/env python3
from pathlib import Path
import tarfile
p=Path(__file__).resolve().parent
out=Path('/home/t3/.cache/kuz-medium-feedback')
out.mkdir(parents=True,exist_ok=True)
with tarfile.open(p/'baseline-v0.9.2.tar.gz') as tf: tf.extractall(out,filter='data')
(out/'src/modes/classic_before_092.zig').write_bytes((out/'src/modes/classic.zig').read_bytes())
(out/'src/modes/classic.zig').write_bytes(Path('src/modes/classic.zig').read_bytes())
for f in ['paired.zig','continuation.zig','contracts.zig','baseline-v0.9.2.tar.gz','run.sh','run-tests.sh','control.sh','short-paired.zig','codegen.zig','after.sh','restrict.sh','excluded-paired.zig','excluded-reversed.zig','classic-retained.zig','run-excluded.sh']:
 (out/f).write_bytes((p/f).read_bytes())
s=(out/'paired.zig').read_text()
s=s.replace('const Before = @import("src/modes/classic_before_092.zig").Modes(kuz.Cipher);\nconst After = kuz.modes.classic;','const Before = kuz.modes.classic;\nconst After = @import("src/modes/classic_before_092.zig").Modes(kuz.Cipher);')
(out/'paired-reversed.zig').write_text(s)
print(out)
