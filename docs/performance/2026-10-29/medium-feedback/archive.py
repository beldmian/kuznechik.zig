#!/usr/bin/env python3
from pathlib import Path
import tarfile,hashlib,json,subprocess
p=Path(__file__).resolve().parent
subprocess.run(['python3',str(p/'prepare.py')],check=True)
out=Path('/home/t3/.cache/kuz-medium-feedback')
(out/'variants').mkdir(exist_ok=True)
for f in (p/'variants').glob('*.zig'): (out/'variants'/f.name).write_bytes(f.read_bytes())
for name in ['pilot-paired.zig','pilot.sh','refine.sh']:(out/name).write_bytes((p/name).read_bytes())
manifest={str(f.relative_to(out)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(out.rglob('*')) if f.is_file()}
(p/'source-sha256.json').write_text(json.dumps(manifest,indent=2)+'\n')
with tarfile.open(p/'candidate-source.tar.gz','w:gz') as t:
 for f in sorted(out.rglob('*')):
  if f.is_file():t.add(f,arcname=str(f.relative_to(out)),recursive=False)
print('archived',len(manifest),'source/input files')
