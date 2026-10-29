#!/usr/bin/env python3
"""Archive a clean, source-only reproduction bundle, then hash all evidence."""
import io, pathlib, subprocess, tarfile, hashlib
root=pathlib.Path(__file__).resolve().parent
baseline=subprocess.check_output(['git','archive','d42d82cd4ece09b6281aac58cdcbe6edef5d43b7','src','build.zig','build.zig.zon'])
files={}
with tarfile.open(fileobj=io.BytesIO(baseline)) as tf:
    for member in tf:
        if member.isfile(): files[member.name]=tf.extractfile(member).read()
files['src/modes/classic_before_090.zig']=files['src/modes/classic.zig']
files['src/modes/classic.zig']=pathlib.Path('src/modes/classic.zig').read_bytes()
for name in ['paired.zig','contracts.zig','continuation.zig','run.sh','run-tests.sh','baseline-v0.9.0.tar.gz']:
    files[name]=(root/name).read_bytes()
s=files['paired.zig'].decode().replace('const Before = @import("src/modes/classic_before_090.zig").Modes(kuz.Cipher);\nconst After = kuz.modes.classic;', 'const Before = kuz.modes.classic;\nconst After = @import("src/modes/classic_before_090.zig").Modes(kuz.Cipher);')
files['paired-reversed.zig']=s.encode()
with tarfile.open(root/'candidate-source.tar.gz','w:gz') as tf:
    for name,data in sorted(files.items()):
        m=tarfile.TarInfo(name);m.size=len(data);m.mode=0o644;m.mtime=0
        tf.addfile(m,io.BytesIO(data))
(root/'source-sha256.txt').write_text(''.join(hashlib.sha256(data).hexdigest()+'  '+name+'\n' for name,data in sorted(files.items())))
(root/'SHA256SUMS').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p.relative_to(root))+'\n' for p in sorted(root.rglob('*')) if p.is_file() and p.name!='SHA256SUMS'))
print('Archived',len(files),'source files')
