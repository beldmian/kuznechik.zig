#!/usr/bin/env python3
"""Audit every actual numbered/named test entry and fail on truncation or skips drift."""
import json,pathlib,re,sys
root=pathlib.Path(sys.argv[1]);out={}
for p in sorted(root.glob('*.log')):
 s=p.read_text();ms=re.findall(r'(?m)^(\d+)/(\d+) (.*?)\.\.\.(OK|SKIP|FAIL)',s)
 if not ms:
  assert 'error:' not in s or p.name=='baseline-znver5-avx2.log',(p,s)
  continue
 total=int(ms[0][1]);assert len(ms)==total,(p,len(ms),total)
 assert [int(m[0]) for m in ms]==list(range(1,total+1)),p
 assert all(int(m[1])==total and m[3]!='FAIL' for m in ms),p
 passed=sum(m[3]=='OK' for m in ms);skips=[m[2] for m in ms if m[3]=='SKIP']
 if '-native-' in p.name and '-basis-' not in p.name:assert (total,passed)==(101,101),(p,total,passed)
 if p.name.startswith('columns-'):
  assert not skips and any('hybrid contributions and endpoint match every byte' in m[2] for m in ms),p
 if '-basis-' in p.name:assert (total,passed)==(102,102),(p,total,passed)
 if '-portable-' in p.name:assert (total,passed)==(95,93),(p,total,passed)
 if '-znver4.' in p.name:assert (total,passed)==(98,98),(p,total,passed)
 if '-znver5-gfni.' in p.name or '-znver5-avx512vbmi.' in p.name:assert (total,passed)==(96,93),(p,total,passed)
 if '-znver5-avx512vl.' in p.name:assert (total,passed)==(101,100),(p,total,passed)
 if '-selfhosted-' in p.name:assert (total,passed)==(96,93),(p,total,passed)
 out[p.name]=dict(entries=total,passed=passed,skipped=skips,names=[m[2] for m in ms],summary=s.splitlines()[-1])
 print(p.name,total,passed,len(skips))
assert out
if len(sys.argv)>2 and sys.argv[2]=='--final':
 required=[]
 for v in ['baseline','boundary','spaced','split2']:
  required += [f'{v}-native-{opt}.log' for opt in ['Debug','ReleaseSafe','ReleaseFast']]
  required += [f'{v}-portable-{opt}.log' for opt in ['Debug','ReleaseSafe','ReleaseFast']]
  required += [f'{v}-basis-native-ReleaseFast.log',f'{v}-selfhosted-Debug.log']
  required += [f'{v}-{cpu}.log' for cpu in ['znver4','znver5-gfni','znver5-avx512vbmi','znver5-avx512vl']]
  assert (root/f'{v}-aarch64.log').exists(),v
 required += [f'columns-{v}.log' for v in json.loads((root/'variants.json').read_text())]
 assert all(name in out for name in required),set(required)-set(out)
 assert len(required)==64,len(required)
 for name in required:
  if name.startswith('columns-'):continue
  kind=name.split('-',1)[1];reference='baseline-'+kind
  assert out[name]['names']==out[reference]['names'],(name,'named test set differs from baseline')
 for opt in ['Debug','ReleaseSafe','ReleaseFast']:
  names=out['baseline-native-'+opt+'.log']['names']
  for fragment in ['optimized cipher matches basic transformations for independent inputs','bulk operations match independent blocks at every batch and tail boundary','hybrid contributions and endpoint match every byte','OCB bounded schedule independent AAD and payload powers full and partial']:
   assert any(fragment in n for n in names),(opt,fragment)
 column_names=out['columns-prefix.log']['names']
 assert all(out[n]['names']==column_names for n in required if n.startswith('columns-'))

(root/'test-audit.json').write_text(json.dumps(out,indent=2)+'\n')
