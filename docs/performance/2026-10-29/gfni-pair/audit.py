#!/usr/bin/env python3
import re,sys,json,pathlib
for f in sys.argv[1:]:
 s=pathlib.Path(f).read_text();entries=re.findall(r'^(\d+)/(\d+) (.*?)\.\.\.(OK|SKIP)\s*$',s,re.M)
 assert entries,(f,'No sequential test entries')
 n=int(entries[0][1]);assert len(entries)==n,(f,len(entries),n)
 assert [int(r[0]) for r in entries]==list(range(1,n+1)),f
 assert all(int(r[1])==n for r in entries),f
 assert not re.search(r'(?<![0-9])[1-9][0-9]* failed|FAIL|error:',s),f
 print(json.dumps({'file':f,'total':n,'passed':sum(r[3]=='OK' for r in entries),'skipped':[r[2] for r in entries if r[3]=='SKIP']}))
