#!/usr/bin/env python3
import collections,hashlib,json,pathlib,re,sys
s=pathlib.Path(sys.argv[1]);out={}
for p in sorted(s.glob('*-codegen.s')):
 text=p.read_text();funcs={}
 symbols=re.findall(r'\.type\s+([\w.]+),@function',text)
 for name in symbols:
  match=re.search(r'^'+re.escape(name)+r':.*?^\.Lfunc_end\d+:',text,re.M|re.S)
  if not match:continue
  lines=[l.strip() for l in match[0].splitlines() if re.match(r'^\s+[a-z][a-z0-9]+\s*',l)]
  counts=collections.Counter(l.split()[0] for l in lines)
  funcs[name]=dict(instructions=len(lines),gfni=sum(v for k,v in counts.items() if k.startswith('vgf')),stackops=sum(('rsp' in l or 'rbp' in l) and '[' in l for l in lines),frame=[l for l in lines if l.startswith('sub\trsp')],counts=counts,calls=re.findall(r'(?m)^\s+(?:call|jmp)\s+([\w.]+)\s*$',match[0]))
 for root in ['encrypt','decrypt','apiEncrypt','apiDecrypt']:
  if root not in funcs:continue
  reached=set()
  def visit(name):
   if name in reached or name not in funcs:return
   reached.add(name)
   for child in funcs[name]['calls']:visit(child)
  visit(root)
  funcs[root]['complete_static']={k:sum(funcs[f][k] for f in reached) for k in ['instructions','gfni','stackops']}
  funcs[root]['complete_symbols']=sorted(reached)
 out[p.stem.replace('-codegen','')]=dict(assembly_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),functions=funcs)
(s/'codegen.json').write_text(json.dumps(out,indent=2)+'\n')
for name,data in out.items():print(name,*(f'{k}:{v["instructions"]}/{v["stackops"]}' for k,v in data['functions'].items()))
