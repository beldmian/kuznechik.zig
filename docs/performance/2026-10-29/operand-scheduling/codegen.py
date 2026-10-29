#!/usr/bin/env python3
import collections,json,pathlib,re,sys
out={}
for p in pathlib.Path(sys.argv[1]).glob('*-codegen.s'):
 text=p.read_text();funcs={}
 for name in ['linear','encrypt','decrypt']:
  match=re.search(r'^'+name+r':.*?^\.Lfunc_end\d+:',text,re.M|re.S)
  if not match:continue
  lines=[l.strip() for l in match[0].splitlines() if re.match(r'^\s+[a-z][a-z0-9]+\s*',l)]
  counts=collections.Counter(l.split()[0] for l in lines)
  funcs[name]=dict(instructions=len(lines),gfni=sum(v for k,v in counts.items() if k.startswith('vgf')),xor=sum(v for k,v in counts.items() if k.startswith('vpxor')),ternary=sum(v for k,v in counts.items() if k.startswith('vptern')),stackops=sum('rsp' in l and '[' in l for l in lines),frame=[l for l in lines if l.startswith('sub\trsp')],counts=counts)
 out[p.stem]=funcs
print(json.dumps(out,indent=2))
