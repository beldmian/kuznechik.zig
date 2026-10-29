#!/usr/bin/env python3
"""Collect sources, raw assembly/timings/logs/receipts, excluding binaries/caches."""
import gzip,hashlib,json,pathlib,subprocess,tarfile
s=pathlib.Path('/home/user/kuz-gfni-pressure')
for pattern in ['pairs-*','reverse-ready*','portable-*']:
 for binary in sorted(s.glob(pattern)):
  if binary.is_file() and binary.read_bytes()[:4]==b'\x7fELF':
   assembly=subprocess.check_output(['objdump','-drwC','-Mintel',str(binary)])
   (s/(binary.name+'-binary.s.gz')).write_bytes(gzip.compress(assembly,mtime=0))
selected=[p for p in s.rglob('*') if p.is_file() and p.suffix in ['.zig','.py','.sh','.json','.jsonl','.log','.txt','.sha256','.s','.gz']]
manifest={str(p.relative_to(s)):hashlib.sha256(p.read_bytes()).hexdigest() for p in selected}
(s/'vm-artifacts.sha256.json').write_text(json.dumps(manifest,indent=2)+'\n');selected.append(s/'vm-artifacts.sha256.json')
with tarfile.open('/home/user/gfni-pressure-evidence.tar.gz','w:gz') as tf:
 for p in sorted(selected):tf.add(p,arcname=str(p.relative_to(s)),recursive=False)
print(hashlib.sha256(pathlib.Path('/home/user/gfni-pressure-evidence.tar.gz').read_bytes()).hexdigest())
