#!/usr/bin/env python3
"""Check VM source hashes against the Git baseline and measured working tree."""
from pathlib import Path
import hashlib, subprocess
P=Path(__file__).resolve().parent
root=P.parents[3]
assert (root/'src/modes/ocb.zig').exists(), root
baseline='d42d82cd4ece09b6281aac58cdcbe6edef5d43b7'
lines=[]
for label in ['baseline-source','source']:
 n=0
 for line in (P/f'logs/{label}-manifest.sha256').read_text().splitlines():
  expected,path=line.split(None,1)
  if label=='baseline-source': data=subprocess.check_output(['git','show',f'{baseline}:{path}'],cwd=root)
  else: data=(root/path).read_bytes()
  actual=hashlib.sha256(data).hexdigest()
  assert actual==expected,(label,path,actual,expected)
  n+=1
 lines.append(f'{label}: {n} source files match '+(baseline if label=='baseline-source' else 'the committed candidate working tree'))
for name in ['baseline','control','candidate']:
 data=(P/f'snapshots/{name}/ocb.zig').read_bytes()
 expected=subprocess.check_output(['git','show',f'{baseline}:src/modes/ocb.zig'],cwd=root) if name!='candidate' else (root/'src/modes/ocb.zig').read_bytes()
 assert data==expected,name
 lines.append(f'{name} OCB snapshot SHA256 {hashlib.sha256(data).hexdigest()}')
for file in ['bench.zig','run-vm.sh']:
 expected=dict((path,digest) for digest,path in (l.split(None,1) for l in (P/'logs/driver-manifest.sha256').read_text().splitlines()))[f'docs/performance/2026-10-29/ocb-schedule/{file}']
 assert hashlib.sha256((P/file).read_bytes()).hexdigest()==expected,file
 lines.append(f'Measured driver {file} SHA256 {expected}')
(P/'artifact-verification.txt').write_text('\n'.join(lines)+'\n')
print('\n'.join(lines))
