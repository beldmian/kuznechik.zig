#!/usr/bin/env python3
from pathlib import Path
import hashlib,json,tarfile,subprocess,re,sys
p=Path(__file__).resolve().parent
base='69d7ed3a2db775071fe331eb667b84283eaafb0d'
expected=subprocess.check_output(['git','archive','--format=tar.gz',base,'src','build.zig','build.zig.zon'])
assert expected==(p/'baseline-v0.9.2.tar.gz').read_bytes(),'baseline archive differs'
manifest=json.loads((p/'source-sha256.json').read_text())
with tarfile.open(p/'candidate-source.tar.gz') as t:
 for name,digest in manifest.items():assert hashlib.sha256(t.extractfile(name).read()).hexdigest()==digest,name
 for f in Path('src').rglob('*.zig'):assert hashlib.sha256(f.read_bytes()).hexdigest()==manifest[str(f)],str(f)
for f in sorted((p/'final').glob('*.jsonl')):
 rows=[json.loads(x) for x in f.read_text().splitlines()]
 assert len(rows)==1088,(f,len(rows))
 for r in rows:
  assert r['checksum']>0 and len(r['before'])==len(r['after'])==9
  assert all(x>0 for x in r['before']+r['after'])
assert len(list((p/'final').glob('*.jsonl')))==6
assert len(json.loads((p/'final/summary.json').read_text()))==1992
for name, count, samples in [('control',416,9),('excluded',320,9),('variants/pilot',416,5),('variants/threshold-inline',1088,9),('variants/noinline',416,9),('variants/vector-scalar',416,9),('variants/inside-dispatch',416,9)]:
 files=list((p/name).glob('*.jsonl'))
 assert len(files)==(2 if name=='variants/pilot' else 4 if name in ['variants/noinline','variants/vector-scalar','variants/inside-dispatch'] else 10 if name=='excluded' else 6),(name,len(files))
 for f in files:
  rows=[json.loads(x) for x in f.read_text().splitlines()]
  assert len(rows)==count,(f,len(rows))
  assert all(len(r['before'])==len(r['after'])==samples and r['checksum']>0 for r in rows),str(f)
assert '0ee27482eb2e7b19fad58579c107364aa93fbfb54be2d2b9c52cef5f955d6225' in (p/'compiler.sha256').read_text()
assert all(json.loads(l).get('id')=='bx_g86mt7cz' for l in (p/'boat-owned.jsonl').read_text().splitlines())
assert Path('src/modes/classic.zig').read_bytes()==(p/'classic-retained.zig').read_bytes()
vm=json.loads((p/'vm-source-sha256.json').read_text())
for name,digest in vm.items():
 if name in manifest: assert digest==manifest[name],name
checks=[]
for f in sorted((p/'validation').glob('*.log')):
 text=f.read_text()
 if f.name=='candidate-aarch64.log':
  assert 'ELF 64-bit' in text and 'ARM aarch64' in text
  continue
 assert '0 failed' in text or re.search(r'All \d+ tests passed\.',text),(f,'not completed')
 entries=re.findall(r'^\d+/\d+ (.+?)\.\.\.(OK|SKIP)',text,re.M)
 if f.name.startswith(('candidate-','baseline-','gate-')):
  assert 'CBC CFB AES independent encryption registers' in text
  assert 'CBC CFB Kuznechik independent encryption registers' in text
  assert 'OCB bounded schedule independent AAD' in text
  assert 'OCB schedule length full-block powers including inclusive L48 endpoint' in text
 checks.append(dict(file=f.name,entries=len(entries),passed=sum(v=='OK' for _,v in entries),skipped=sum(v=='SKIP' for _,v in entries)))
 if f.name in ['candidate-native-Debug-llvm.log','candidate-native-ReleaseSafe.log','candidate-native-ReleaseFast.log','baseline-native-ReleaseFast.log']:
  assert len(entries)==103 and all(status=='OK' for _,status in entries),f
 elif f.name=='candidate-native-Debug.log' or f.name.startswith('gate-'):
  assert len(entries)==98 and sum(status=='SKIP' for _,status in entries)==3,f
 elif '-baseline-' in f.name:
  assert len(entries)==97 and sum(status=='SKIP' for _,status in entries)==2,f
 elif f.name in ['contracts.log','continuation.log']:
  assert len(entries)==8 and all(status=='OK' for _,status in entries),f

assert len(checks)==13,len(checks)
assert (p/'validation/validation-complete.txt').read_text().strip()=='ALL VALIDATION COMMANDS PASSED'
(p/'checks.json').write_text(json.dumps(checks,indent=2)+'\n')
if '--before-delete' not in sys.argv:
 text=(p/'boat-deletion-status.json').read_text()
 assert 'completed' in text and 'bx_g86mt7cz' in text
print('Verified exact v0.9.2 baseline, source archive, VM source binding, 6528 final rows / 58752 measured pairs, 13 test receipts, linked AArch64 build'+(' (before deletion)' if '--before-delete' in sys.argv else ', completed VM deletion'))
