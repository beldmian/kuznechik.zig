#!/usr/bin/env python3
import collections,json,pathlib,re,sys
out={}
for p in sorted(pathlib.Path(sys.argv[1]).glob('*-codegen.s')):
 funcs={}
 for name in ['encrypt','decrypt']:
  m=re.search(r'^'+name+r':.*?^\.Lfunc_end\d+:',p.read_text(),re.M|re.S)
  if not m:continue
  ls=[l.strip() for l in m[0].splitlines() if re.match(r'^\s+[a-z][a-z0-9]+\s+',l)]
  cc=collections.Counter(l.split()[0] for l in ls)
  funcs[name]=dict(instructions=len(ls),gfni=sum(v for k,v in cc.items() if k.startswith('vgf')),stackops=sum(bool(re.search(r'\[(?:rsp|rbp)\b',l)) for l in ls),frame=[l for l in ls if l.startswith('sub\trsp')],counts=cc)
 out[p.stem]=funcs
print(json.dumps(out,indent=2))
