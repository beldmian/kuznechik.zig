#!/usr/bin/env python3
import pathlib,tarfile,hashlib,sys,subprocess
p=pathlib.Path(sys.argv[1]);out=pathlib.Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
with tarfile.open(p) as t:
 assert all(not x.name.startswith('/') and '..' not in pathlib.PurePosixPath(x.name).parts for x in t)
 t.extractall(out,filter='data')
count=0
for line in (out/'evidence/source.sha256').read_text().splitlines():
 h,name=line.split('  ',1);assert hashlib.sha256((out/name).read_bytes()).hexdigest()==h,name;count+=1
base='567ab5e19531c2d746f6bfee489f58177933ea61'
for f in (out/'baseline/src').rglob('*'):
 if not f.is_file():continue
 rel=f.relative_to(out/'baseline');exact=subprocess.check_output(['git','show',f'{base}:{rel}'])
 assert exact==f.read_bytes(),str(rel)
for variant in ['candidate','narrow','control','initial-candidate','inside','switch','wide','wide-switch']:
 for f in (out/variant/'src').rglob('*'):
  if not f.is_file():continue
  rel=f.relative_to(out/variant)
  if str(rel) not in ['src/kuznechik.zig','src/gfni_pair.zig']:
   assert (out/'baseline'/rel).read_bytes()==f.read_bytes(),(variant,str(rel))
if '--candidate-matches-worktree' in sys.argv:
 for f in (out/'candidate/src').rglob('*'):
  if not f.is_file():continue
  rel=f.relative_to(out/'candidate');assert pathlib.Path(rel).read_bytes()==f.read_bytes(),str(rel)
else:
 for f in (out/'baseline/src').rglob('*'):
  if not f.is_file():continue
 rel=f.relative_to(out/'baseline');assert pathlib.Path(rel).read_bytes()==f.read_bytes(),str(rel)
 assert not pathlib.Path('src/gfni_pair.zig').exists()
print(f'{count} Zig source hashes verified, all source fixtures compared; exact v0.9.3 baseline; only owned files differ in experiments; working tree verified.')
