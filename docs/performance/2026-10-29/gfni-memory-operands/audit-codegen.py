#!/usr/bin/env python3
"""Audit actual LLVM operand contracts and complete isolated assembly."""
import collections,gzip,hashlib,json,pathlib,re,struct,sys
s=pathlib.Path(sys.argv[1]); result={}
def mul(a,b):
 p=0
 for i in range(8):
  if b>>i&1:p^=a<<i
 for i in range(14,7,-1):
  if p>>i&1:p^=0x1c3<<(i-8)
 return p
def mat(c):
 return sum(((mul(1<<i,c)>>j)&1)<<((7-j)*8+i) for i in range(8) for j in range(8))
all_matrices={mat(c) for c in range(256)}
for v in ['baseline','explicit-clobber','explicit-read']:
 ll=(s/f'{v}-codegen.ll').read_text();asm=(s/f'{v}-codegen.s').read_text()
 linear=re.search(r'^linear:.*?^\.Lfunc_end\d+:',asm,re.M|re.S)[0]
 gf=[l.strip() for l in linear.splitlines() if 'vgf2p8affineqb' in l]
 assert len(gf)==70,(v,len(gf));assert all('qword ptr' in l and '{1to8}' in l for l in gf),v
 calls=[l for l in ll.splitlines() if 'asm "vgf2p8affineqb $$0, ${2}{1to8}, ${1}, ${0}"' in l]
 d=dict(llvm_sha256=hashlib.sha256(ll.encode()).hexdigest(),linear_gfni=gf)
 if v!='baseline':
  assert calls,v
  assert all('"=v,v,*m,' in l and 'elementtype([1 x i64])' in l for l in calls),v
  assert all(('~{memory}' in l)==(v=='explicit-clobber') for l in calls),v
  assert all('[rip +' in l for l in gf),v
  constants={m[0]:int(m[1])&((1<<64)-1) for m in re.findall(r'^(@\d+) = .*constant \[1 x i64\] \[i64 (-?\d+)\]',ll,re.M)}
  symbols=[re.search(r'elementtype\(\[1 x i64\]\) (@\d+)',l)[1] for l in calls]
  assert all(c in constants for c in symbols)
  expected=all_matrices
  assert all(constants[c] in expected for c in symbols)
  d.update(explicit_calls=len(calls),operand_type='[1 x i64], exactly eight bytes',memory_clobber=v=='explicit-clobber',constant_matrices={c:constants[c] for c in sorted(set(symbols))},constant_bytes=8*len(set(symbols)),rip_relative_all_linear=True,stack_broadcasts=0)
 data=(s/f'{v}-codegen.o').read_bytes(); shoff=struct.unpack_from('<Q',data,40)[0]; entsize,num,names=struct.unpack_from('<HHH',data,58)
 hdr=[struct.unpack_from('<IIQQQQIIQQ',data,shoff+i*entsize) for i in range(num)]; shstr=data[hdr[names][4]:hdr[names][4]+hdr[names][5]]
 d['text_sha256']=hashlib.sha256(next(data[t[4]:t[4]+t[5]] for t in hdr if shstr[t[0]:].split(b'\0',1)[0]==b'.text')).hexdigest()
 d['elf_sections']={shstr[t[0]:].split(b'\0',1)[0].decode():t[5] for t in hdr if t[5]}
 result[v]=d
rodata=json.loads((s/'timed-rodata.json').read_text()) if (s/'timed-rodata.json').exists() else {}
if rodata:
 receipts={line.split()[1]:line.split()[0] for line in (s/'binaries.sha256').read_text().splitlines()}
 assert len(rodata)==9
 for binary,meta in rodata.items():assert receipts[binary]==meta['binary_sha256'],binary
for p in s.glob('pairs-*.objdump.gz'):
 data=gzip.decompress(p.read_bytes()).decode()
 if '-portable.' in p.name:assert not re.search(r'\bzmm\d|\bvgf2p8',data),p
 d=dict(sha256=hashlib.sha256(data.encode()).hexdigest(),portable_no_gfni_or_zmm='-portable.' in p.name)
 binary=p.name.replace('.objdump.gz','')
 if binary in rodata and binary.startswith('pairs-explicit-') and '-portable' not in binary:
  meta=rodata[binary];raw=gzip.decompress((s/(binary+'.rodata.gz')).read_bytes());assert hashlib.sha256(raw).hexdigest()==meta['rodata_sha256']
  targets=re.findall(r'vgf2p8affineqb[^\n]*QWORD BCST \[rip[^\n]*# ([0-9a-f]+)',data)
  assert targets,p
  values=[]
  for target in targets:
   offset=int(target,16)-meta['address'];assert 0<=offset<=len(raw)-8
   value=int.from_bytes(raw[offset:offset+8],'little');assert value in all_matrices,(p,target,value)
   values.append(value)
  d.update(verified_rip_qword_broadcasts=len(values),distinct_matrices=len(set(values)),all_resolved_values_are_field_matrices=True)
 result[p.name]=d
(s/'operand-audit.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({v:{k:d for k,d in result[v].items() if k not in ['linear_gfni','constant_matrices','elf_sections']} for v in ['baseline','explicit-clobber','explicit-read']},indent=2))
