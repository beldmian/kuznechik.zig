#!/usr/bin/env python3
"""Verify immutable baseline, source/scope, complete sample grid and named tests.
Accepts evidence/ unpacked from evidence.tar.gz; never executes benchmark code.
"""
from pathlib import Path
import collections,gzip,hashlib,json,re,subprocess,tarfile,sys
p=Path(__file__).resolve().parent
base='567ab5e19531c2d746f6bfee489f58177933ea61'
h=lambda x:hashlib.sha256(x).hexdigest()
assert subprocess.check_output(['git','archive','--format=tar.gz',base,'src','build.zig','build.zig.zon'])==(p/'baseline-v0.9.3.tar.gz').read_bytes()
manifest=json.loads((p/'source-sha256.json').read_text())
with tarfile.open(p/'candidate-source.tar.gz') as t:
 assert set(t.getnames())==set(manifest)
 sources={n:t.extractfile(n).read() for n in manifest}
 for n,d in sources.items():assert h(d)==manifest[n],n
with tarfile.open(p/'baseline-v0.9.3.tar.gz') as t:
 original={m.name:t.extractfile(m).read() for m in t.getmembers() if m.isfile()}
for n,d in original.items():
 if n!='src/modes/classic.zig':assert sources[n]==d,n
b=original['src/modes/classic.zig'].decode(); c=sources['src/modes/classic.zig'].decode()
old='''                // Keep unmeasured medium widths on their existing scalar path.
                const batch_enabled = switch (iv_blocks) {
                    2, 3, 4, 8, 16, 24, 31, 32, 63 => true,
                    else => iv_blocks >= 64,
                };'''
assert c.startswith(b.replace(old,'                const batch_enabled = iv_blocks >= 2;'))
assert c[len(b.replace(old,'                const batch_enabled = iv_blocks >= 2;')):].startswith('\n// Only the newly eligible CBC widths:')
assert h(Path('src/modes/classic.zig').read_bytes())==manifest['src/modes/classic.zig']
assert sources['src/modes/classic_before_093.zig']==sources['src/modes/classic_control_093.zig']==original['src/modes/classic.zig']
for e in (json.loads(l) for l in (p/'boat-owned.jsonl').read_text().splitlines()):assert e['id']=='bx_dzmcsqs6'
with tarfile.open(p/'evidence.tar.gz') as t:
 files={m.name:t.extractfile(m).read() for m in t.getmembers() if m.isfile()}
assert 'c61c5da6edeea14ca51ecd5e4520c6f4189ef5250383db33d01848293bfafe05' in files['compiler.sha256'].decode()
assert '0ee27482eb2e7b19fad58579c107364aa93fbfb54be2d2b9c52cef5f955d6225' in files['compiler.sha256'].decode()
vm=json.loads(files['evidence/vm-source-sha256.json'])
assert set(vm)==set(manifest)
for n,digest in vm.items():assert manifest[n]==digest,n
for n in ['evidence/timing-complete.txt','evidence/after-complete.txt','evidence/validation/validation-complete.txt']:assert 'PASSED' in files[n].decode(),n
widths=list(range(1,66))+[128]
expected=collections.Counter((w,n,s) for w in widths for n in [16,32,48,64,80,112,128,144,w*16-16,w*16,w*16+16,w*32-16,w*32+16,1024,2048,16384] if n for s in [False,True])
for target in ['native','baseline']:
 nm=files[f'evidence/assembly/{target}.nm'].decode()
 assert set(re.findall(r'\b((?:before|after)_cbc\d+)$',nm,re.M))=={f'{side}_cbc{w}' for side in ['before','after'] for w in widths}
rows_count=0
for group in ['final','control']:
 fs={n:d for n,d in files.items() if n.startswith('evidence/'+group+'/') and n.endswith('.jsonl')}
 assert len(fs)==10,(group,len(fs))
 runs={'forward1':(271828,0),'forward2':(314159,3)}
 if group=='final':runs.update({'reverse':(1618033,1),'forward3':(424242,0),'reverse2':(8675309,3)})
 else:runs.update({'forward3':(1618033,1),'forward4':(424242,0),'forward5':(8675309,3)})
 assert set(fs)=={f'evidence/{group}/{target}-{run}.jsonl' for target in ['native','baseline'] for run in runs}
 for n,d in fs.items():
  rows=[json.loads(l) for l in d.decode().splitlines()]
  assert len(rows)==2110,(n,len(rows))
  run=Path(n).stem.split('-',1)[1]
  assert all((r['seed'],r['layout'])==runs[run] and r['offset']==16+r['layout']%2 and r['reps']==max(8,65536//r['bytes']) for r in rows),n
  assert collections.Counter((r['m'],r['bytes'],r['split1']) for r in rows)==expected,n
  assert all(r['checksum']>0 and len(r['before'])==len(r['after'])==9 and all(x>0 for x in r['before']+r['after']) for r in rows),n
  rows_count+=len(rows)
local=(p/'local-focused.log').read_text()
assert [(int(i),int(j)) for i,j in re.findall(r'^(\d+)/(\d+) .+?\.\.\.(?:OK|SKIP)',local,re.M)]==[(i,7) for i in range(1,8)]
assert 'All 7 tests passed.' in local and 'CBC remaining widths AES physical shift register' in local and 'CBC remaining widths Kuznechik physical shift register' in local
checks=[]
for n,d in files.items():
 if not n.startswith('evidence/validation/') or not n.endswith('.log'):continue
 text=d.decode(); name=Path(n).name
 if name=='candidate-aarch64.log':
  assert 'ELF 64-bit' in text and 'ARM aarch64' in text
  continue
 entries=re.findall(r'^(\d+)/(\d+) (.+?)\.\.\.(OK|SKIP)',text,re.M)
 assert entries,(n,'empty inventory')
 total=len(entries)
 assert [(int(i),int(j)) for i,j,_,_ in entries]==[(i,total) for i in range(1,total+1)],n
 passed=sum(v=='OK' for _,_,_,v in entries); skipped=total-passed
 if name.startswith('baseline-'):expected_count=(103,0) if 'native' in name else (95,2)
 elif name=='candidate-native-Debug.log' or name.startswith('gate-'):expected_count=(97,3)
 elif '-baseline-' in name:expected_count=(97,2)
 elif name in ['contracts.log','continuation.log']:expected_count=(8,0)
 else:expected_count=(105,0)
 assert (passed,skipped)==expected_count,(n,passed,skipped,expected_count)
 assert '0 failed' in text or re.search(r'All \d+ tests passed\.',text),n
 if name.startswith(('baseline-','candidate-','gate-')):
  assert 'CBC CFB AES independent encryption registers' in text and 'CBC CFB Kuznechik independent encryption registers' in text
  assert 'OCB bounded schedule independent AAD' in text and 'OCB schedule length full-block powers including inclusive L48 endpoint' in text
  if not name.startswith('baseline-'):
   assert 'CBC remaining widths AES physical shift register' in text and 'CBC remaining widths Kuznechik physical shift register' in text
 checks.append(dict(file=name,entries=total,passed=passed,skipped=skipped))
assert len(checks)==14,len(checks)
(p/'checks.json').write_text(json.dumps(sorted(checks,key=lambda x:x['file']),indent=2)+'\n')
if '--before-delete' not in sys.argv:
 status=json.loads((p/'boat-deletion-status.json').read_text())
 assert 'completed' in json.dumps(status) and 'bx_dzmcsqs6' in json.dumps(status)
print(f'PASS: exact v0.9.3, source/scope and remote source hashes, {rows_count} final/control rows / {rows_count*9} measured pairs, 14 sequential named test receipts, linked AArch64'+(' (before deletion)' if '--before-delete' in sys.argv else ', completed exclusive VM deletion'))
