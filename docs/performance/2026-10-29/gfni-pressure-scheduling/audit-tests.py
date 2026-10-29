#!/usr/bin/env python3
"""Verify sequential names/status/counts, not merely tool exit codes."""
import json,pathlib,re,sys
root=pathlib.Path(sys.argv[1]);out={}
for p in sorted(root.glob('*.log')):
 text=p.read_text();matches=re.findall(r'(?m)^(\d+)/(\d+) (.*?)\.\.\.(OK|SKIP|FAIL)',text)
 if not matches:continue
 total=int(matches[0][1]);assert len(matches)==total,(p,len(matches),total)
 assert [int(m[0]) for m in matches]==list(range(1,total+1)),p
 assert all(int(m[1])==total and m[3]!='FAIL' for m in matches),p
 passed=sum(m[3]=='OK' for m in matches);skips=[m[2] for m in matches if m[3]=='SKIP']
 if '-native-' in p.name:assert (total,passed)==(103,103),(p,total,passed)
 if '-portable-' in p.name:assert (total,passed,len(skips))==(97,95,2),(p,total,passed)
 if '-selfhosted-' in p.name or any(c in p.name for c in ['znver5-gfni','znver5-avx512vbmi','znver5-avx2']):assert (total,passed,len(skips))==(98,95,3),(p,total,passed)
 if '-znver4.' in p.name:assert(total,passed)==(100,100),(p,total,passed)
 if '-algebra.' in p.name:assert(total,passed)==(1,1),(p,total,passed)
 out[p.name]=dict(entries=total,passed=passed,skipped=skips,names=[m[2] for m in matches],summary=text.splitlines()[-1])
 print(p.name,total,passed,len(skips))
required={f'{v}-native-ReleaseFast.log' for v in ['baseline','ready00','ready12','ready18','ready19']}
for v in ['baseline','ready00']:
 required.update(f'{v}-native-{opt}.log' for opt in ['Debug','ReleaseSafe'])
 required.update(f'{v}-portable-{opt}.log' for opt in ['Debug','ReleaseSafe','ReleaseFast'])
 required.add(f'{v}-selfhosted-Debug.log')
 required.update(f'{v}-{cpu}.log' for cpu in ['znver4','znver5-gfni','znver5-avx512vbmi','znver5-avx2'])
required.update(f'{v}-algebra.log' for v in ['baseline','candidate','ready00','ready12','ready18','ready19'])
assert required <= set(out),('Missing complete logs',sorted(required-set(out)))
# Compare names within each profile, catching equal-sized stale binaries too.
for profile in ['native-Debug','native-ReleaseSafe','native-ReleaseFast','portable-Debug','portable-ReleaseSafe','portable-ReleaseFast']:
 names=[v['names'] for k,v in out.items() if profile in k]
 assert not names or all(v==names[0] for v in names),profile
(root/'test-audit.json').write_text(json.dumps(out,indent=2)+'\n')
