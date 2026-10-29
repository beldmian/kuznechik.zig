#!/usr/bin/env python3
import re,pathlib,collections,json,sys
results=[]
for arg in sys.argv[1:]:
 p=pathlib.Path(arg);files={};active=None;fn=None;byfn=collections.defaultdict(collections.Counter)
 for line in p.read_text().splitlines():
  m=re.match(r'\s*\.file\s+(\d+)\s+"([^"]*)"\s+"([^"]*)"',line)
  if m:files[int(m[1])]=m[2]+'/'+m[3]
  m=re.match(r'\s*\.type\s+([^,]+),@function',line)
  if m:fn=m[1]
  m=re.match(r'\s*\.loc\s+(\d+)\s+',line)
  if m:active=int(m[1])
  m=re.match(r'\t([a-z][a-z0-9]+)\s+([^#]*)',line)
  if m and 'gfni_pair.zig' in files.get(active,''):
   op=m[1];args=m[2]
   width='zmm' if 'zmm' in args else 'ymm' if 'ymm' in args else 'other'
   byfn[fn][op+':'+width]+=1
 results.append(dict(file=str(p),functions={k:dict(v) for k,v in byfn.items()}))
print(json.dumps(results,indent=2))
