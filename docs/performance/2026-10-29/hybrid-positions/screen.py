#!/usr/bin/env python3
"""Independent field/column derivation and finite subset screening, no timings."""
import collections,itertools,json,pathlib,random,re,sys
stage=pathlib.Path(sys.argv[1]); variants=json.loads((stage/'variants.json').read_text())
def mul(a,b,p):
 y=0
 for _ in range(8):
  if b&1:y^=a
  a=((a<<1)^(p if a&128 else 0))&255;b>>=1
 return y
K=[[mul(a,b,0x1c3) for b in range(256)] for a in range(256)]
A=[[mul(a,b,0x11b) for b in range(256)] for a in range(256)]
basis=[1]
for _ in range(7):basis.append(A[basis[-1]][0x30])
def xor(xs):
 r=0
 for x in xs:r^=x
 return r
F=[xor(basis[i] for i in range(8) if x>>i&1) for x in range(256)]; Finv=[F.index(x) for x in range(256)]
assert len(set(F))==256
for a in range(256):
 for b in range(256):assert F[K[a][b]]==A[F[a]][F[b]]
C=[148,32,133,16,194,192,1,251,1,192,194,16,133,32,148,1]
def linear(x,inv):
 x=list(x)
 for _ in range(16):
  if inv:x=x[1:]+[x[0]^xor(K[C[i]][x[i+1]] for i in range(15))]
  else:x=[xor(K[c][v] for c,v in zip(C,x))]+x[:-1]
 return x
cols={str(inv):[linear([int(i==j) for i in range(16)],inv) for j in range(16)] for inv in (False,True)}
for inv in (False,True):
 for pos in range(16):
  col=cols[str(inv)][pos]
  for v in range(256):assert linear([v if i==pos else 0 for i in range(16)],inv)==[Finv[A[F[v]][F[c]]] for c in col]
# Verify S-box cancellation and complete mixed-column rounds independently.
text=(stage/'baseline/definitions.zig').read_text()
pi=[int(x,16) for x in re.findall(r'0x[0-9a-fA-F]+',re.search(r'pub const pi_table:.*?= \.\{(.*?)\};',text,re.S)[1])]
pinv=[pi.index(i) for i in range(256)]
assert len(pi)==256
for x in range(256):assert pinv[pi[x]]==x
rng=random.Random(94100)
for spec in variants.values():
 selected=spec['selected'];rest=spec['remainder']
 for inv,first in [(False,False),(True,False),(True,True)]:
  cc=cols[str(inv)]
  for _ in range(128):
   x=[rng.randrange(256) for _ in range(16)];seed=[rng.randrange(256) for _ in range(16)]
   sub=x if first else [pinv[v] if inv else pi[v] for v in x]
   gfni=[Finv[xor(A[F[sub[i]]][F[cc[i][j]]] for i in selected)] for j in range(16)]
   # In first inverse round, original inverse LUT S-box cancels Pi(index).
   table_sub=[pinv[pi[v]] if first else pinv[v] if inv else pi[v] for v in x]
   lut=[xor(K[table_sub[i]][cc[i][j]] for i in rest) for j in range(16)]
   assert [a^b^k for a,b,k in zip(gfni,lut,seed)]==[a^k for a,k in zip(linear(sub,inv),seed)]
# A scalar estimate only groups extraction shapes. It is not a CPU cost model.
# GFNI bytes 0/8 need truncation only; LUT bytes 0/8 use left-shift,
# other LUT bytes use right-shift. High-byte extraction allows alternate encodings.
classes=collections.Counter()
for subset in itertools.combinations(range(16),5):
 classes[(sum(i in (0,8) for i in subset),sum(i<8 for i in subset),sum(i in (7,15) for i in subset))]+=1
for v in variants.values():
 pos=v['selected'];v['zero_shift_gfni']=sum(i in (0,8) for i in pos);v['gfni_word_split']=[sum(i<8 for i in pos),sum(i>=8 for i in pos)]
 v['active_lut_bytes_per_direction']=11*4096
 v['unit_coefficients']={key:sum(x==1 for i in pos for x in columns[i]) for key,columns in cols.items()}
# Dense grouping equals baseline at prefix; do not re-test old width/group counts.
out={'subsets_total':4368,'compiled_structured_families':len(variants),'shape_classes':[{'shape':k,'count':v} for k,v in sorted(classes.items())], 'field_basis':basis,'columns':cols,'encoded_columns':{key:[[F[x] for x in row] for row in cc] for key,cc in cols.items()},'verified_raw_basis_cases':8192,'verified_field_products':65536,'verified_mixed_seeded_rounds':16*3*128,'first_inverse_rule':'GFNI F(x), LUT Pi(x), since Pi_inv(Pi(x))=x; final endpoint unchanged','variants':variants,'limitations':'Shape classes and coefficient counts are descriptive only. The structured sample is not exhaustive and algebra does not predict compiler scheduling.'}
(stage/'screen.json').write_text(json.dumps(out,indent=2)+'\n')
