#!/usr/bin/env python3
"""Check actual test names and sequential counts, not just exit status."""
import json,pathlib,re,sys
root=pathlib.Path(sys.argv[1]);out={}
for p in sorted(root.glob('*.log')):
 text=p.read_text();matches=re.findall(r'(?m)^(\d+)/(\d+) (.*?)\.\.\.(OK|SKIP|FAIL)',text)
 if not matches:continue
 total=int(matches[0][1]);assert len(matches)==total,(p,len(matches),total)
 assert [int(m[0]) for m in matches]==list(range(1,total+1)),p
 assert all(int(m[1])==total and m[3]!='FAIL' for m in matches),p
 passed=sum(m[3]=='OK' for m in matches);skips=[m[2] for m in matches if m[3]=='SKIP']
 if '-native-' in p.name:assert total==73 and passed==73,p
 if '-portable-' in p.name:assert total==67 and passed==65 and len(skips)==2,p
 out[p.name]=dict(entries=total,passed=passed,skipped=skips,names=[m[2] for m in matches],summary=text.splitlines()[-1])
 print(p.name,total,passed,len(skips))
assert out,'No test logs audited'
(root/'test-audit.json').write_text(json.dumps(out,indent=2)+'\n')
