#!/usr/bin/env python3
"""Create source-only measurements; never creates a Git checkout."""
import pathlib, subprocess, tarfile, io
out=pathlib.Path('/home/t3/.cache/kuz-feedback-next')
out.mkdir(parents=True,exist_ok=True)
evidence=pathlib.Path(__file__).resolve().parent
archive=subprocess.check_output(['git','archive','d42d82cd4ece09b6281aac58cdcbe6edef5d43b7','src','build.zig','build.zig.zon'])
with tarfile.open(fileobj=io.BytesIO(archive)) as tf: tf.extractall(out,filter='data')
(out/'src/modes/classic_before_090.zig').write_bytes((out/'src/modes/classic.zig').read_bytes())
(out/'src/modes/classic.zig').write_bytes(pathlib.Path('src/modes/classic.zig').read_bytes())
for f in ['paired.zig','run.sh','run-tests.sh','contracts.zig','continuation.zig','baseline-v0.9.0.tar.gz']:
    (out/f).write_bytes((evidence/f).read_bytes())
s=(out/'paired.zig').read_text()
# Actual module source order is reversed, as well as logical labels.
s=s.replace('const Before = @import("src/modes/classic_before_090.zig").Modes(kuz.Cipher);\nconst After = kuz.modes.classic;', 'const Before = kuz.modes.classic;\nconst After = @import("src/modes/classic_before_090.zig").Modes(kuz.Cipher);')
(out/'paired-reversed.zig').write_text(s)
print(out)
