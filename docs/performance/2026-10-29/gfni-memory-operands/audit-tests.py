#!/usr/bin/env python3
import json,pathlib,re,sys
s=pathlib.Path(sys.argv[1]); out={}; required=set()
for v in ['baseline','explicit-clobber','explicit-read']:
 for profile in ['native-Debug','native-ReleaseSafe','native-ReleaseFast','portable-Debug','portable-ReleaseSafe','portable-ReleaseFast','selfhosted-Debug','znver4','znver5-gfni','znver5-avx512vbmi','znver5-avx2','algebra','products']:
  name=f'{v}-{profile}.log'; required.add(name);text=(s/name).read_text()
  rows=re.findall(r'(?m)^(\d+)/(\d+) (.*?)\.\.\.(OK|SKIP|FAIL)',text)
  assert rows,name
  total=int(rows[0][1]); assert len(rows)==total and [int(r[0]) for r in rows]==list(range(1,total+1)),name
  assert all(int(r[1])==total and r[3]!='FAIL' for r in rows),name
  passed=sum(r[3]=='OK' for r in rows);skips=[r[2] for r in rows if r[3]=='SKIP']
  expected=(105,105) if profile.startswith('native-') else (99,97) if profile.startswith('portable-') else (102,102) if profile=='znver4' else (1,1) if profile=='algebra' else (2,2) if profile=='products' else (100,97)
  assert(total,passed)==expected,(name,total,passed,expected)
  assert ('All '+str(total)+' tests passed.') in text or '0 failed' in text,name
  out[name]=dict(total=total,passed=passed,skipped=skips,inventory=[dict(number=int(r[0]),name=r[2],status=r[3]) for r in rows],summary=text.splitlines()[-1])
  print(name,total,passed,len(skips))
 for profile in ['aarch64']:
  assert (s/f'{v}-{profile}.log').read_text()==''
  assert 'ARM aarch64' in (s/f'{v}-aarch64-file.txt').read_text()
for profile in ['native-Debug','native-ReleaseSafe','native-ReleaseFast','portable-Debug','portable-ReleaseSafe','portable-ReleaseFast','selfhosted-Debug','znver4','znver5-gfni','znver5-avx512vbmi','znver5-avx2','algebra','products']:
 inventories=[out[f'{v}-{profile}.log']['inventory'] for v in ['baseline','explicit-clobber','explicit-read']]
 assert all(i==inventories[0] for i in inventories),profile
(s/'test-audit.json').write_text(json.dumps(out,indent=2)+'\n')
