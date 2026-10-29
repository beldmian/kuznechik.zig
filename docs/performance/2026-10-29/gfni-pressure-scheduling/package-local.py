#!/usr/bin/env python3
"""Build concise delivery from a locally verified complete VM evidence copy."""
import hashlib,json,pathlib,shutil,sys,tarfile
s=pathlib.Path(sys.argv[1]);out=pathlib.Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
vm=json.loads((s/'vm-artifacts.sha256.json').read_text())
assert all(hashlib.sha256((s/f).read_bytes()).hexdigest()==h for f,h in vm.items())
for archive,files in [
 ('measured-sources.tar.xz',[p for v in json.loads((s/'source-audit.json').read_text())['variants'] for p in (s/v).rglob('*') if p.is_file()]+list(s.glob('*.zig'))+[s/'schedules.json']),
 ('timed-binary-assembly.tar.gz',list(s.glob('*-binary.s.gz'))),
 ('all-assembly.tar.xz',list(s.glob('*-codegen.s'))),
 ('raw-timings.tar.gz',[p for p in s.glob('*.jsonl') if p.name.startswith(('explore-','confirm-','reverse-','portable-'))]),
 ('test-logs.tar.gz',[p for p in s.glob('*.log') if any(t in p.name for t in ['native-','portable-','selfhosted-','znver','-algebra','-aarch64'])])]:
 with tarfile.open(out/archive,'w:xz' if archive.endswith('.xz') else 'w:gz') as tf:
  for p in sorted(files):tf.add(p,arcname=str(p.relative_to(s)),recursive=False)
 # Read every member back, verifying compressed archive contents independently.
 with tarfile.open(out/archive) as tf:
  assert {m.name:hashlib.sha256(tf.extractfile(m).read()).hexdigest() for m in tf.getmembers() if m.isfile()}=={str(p.relative_to(s)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
for pattern in ['*.json','*.txt','*.sha256','screen.log','build-pairs.log','explore.log','confirm.log','validate.log']:
 for p in s.glob(pattern):shutil.copyfile(p,out/p.name)
print('Verified all VM hashes and all packaged archive members locally.')
