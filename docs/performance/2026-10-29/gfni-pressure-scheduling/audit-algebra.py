#!/usr/bin/env python3
"""Each exact schedule vs independent raw recurrence, both directions and key scales.
No baseline DAG is used as the expected answer. Verifies every byte/binary basis
and 1024 dense keyed inputs per direction for all 23 source schedules.
"""
import hashlib,json,pathlib,random,sys
s=pathlib.Path(sys.argv[1]);p=json.loads((s/'proof.json').read_text());nn=p['nodes'];oo=p['outputs'];C=[148,32,133,16,194,192,1,251,1,192,194,16,133,32,148,1]
def bitmul(a,b):
 out=0
 for _ in range(8):
  if b&1:out^=a
  a=((a<<1)^(0x1c3 if a&128 else 0))&255;b>>=1
 return out
M=[[bitmul(a,b) for b in range(256)] for a in range(256)]
rs=p['row_scale'];cs=p['column_scale'];ri=[M[c].index(1) for c in rs];ci=[M[c].index(1) for c in cs]
def oracle(x,inv):
 x=x[:]
 for _ in range(16):
  if inv:
   last=x[0]
   for i in range(15):last^=M[C[i]][x[i+1]]
   x=x[1:]+[last]
  else:
   first=0
   for i in range(16):first^=M[C[i]][x[i]]
   x=[first]+x[:-1]
 return x
def evaluate(order,raw,key,inv):
 x=[M[ci[15-i if inv else i]][raw[i]] for i in range(16)];seed=[M[rs[15-i if inv else i]][key[i]] for i in range(16)]
 if inv:x.reverse();seed.reverse()
 v=[0]*len(nn)
 for i in range(16):v[i+1]=x[i]
 for i in order:
  n=nn[i];v[i]=v[n[1]]^v[n[2]] if n[0]=='xor' else M[n[2]][v[n[1]]]
 y=[v[o]^seed[j] for j,o in enumerate(oo)]
 if inv:y.reverse()
 return [M[ri[15-i if inv else i]][y[i]] for i in range(16)]
cases=[];rng=random.Random(902970)
for inv in [False,True]:
 for pos in range(16):
  for val in range(256):
   x=[0]*16;x[pos]=val;cases.append((inv,x,[0]*16,oracle(x,inv)))
 for _ in range(1024):
  x=[rng.randrange(256) for i in range(16)];key=[rng.randrange(256) for i in range(16)]
  cases.append((inv,x,key,[a^b for a,b in zip(oracle(x,inv),key)]))
out={}
for name,d in json.loads((s/'schedules.json').read_text()).items():
 for inv,x,key,expected in cases:assert evaluate(d['order'],x,key,inv)==expected,(name,inv,x,key)
 out[name]=dict(source_sha256=d['source_sha256'],byte_basis_per_direction=4096,binary_basis_per_direction=128,seeded_dense_per_direction=1024,oracle='independent raw field recurrence with forward/reversed row/column/key scaling; not baseline DAG',passed=True)
 print(name,'4096 byte + 128 included binary + 1024 seeded dense per direction: passed',flush=True)
(s/'independent-schedule-algebra.json').write_text(json.dumps(out,indent=2)+'\n')
