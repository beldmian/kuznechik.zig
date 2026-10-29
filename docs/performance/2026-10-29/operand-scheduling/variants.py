#!/usr/bin/env python3
"""Emit source-only scheduling experiments from the validated released graph.
Run the fixed-baseline prepare.py first. Does not create Git checkouts.
"""
import argparse, collections, itertools, json, pathlib, re, shutil
ap=argparse.ArgumentParser();ap.add_argument('stage',type=pathlib.Path);args=ap.parse_args()
s=args.stage
p=json.loads((s/'proof.json').read_text());nodes=p['nodes'];outputs=p['outputs']
def deps(i):
 n=nodes[i];return n[1:] if n[0]=='xor' else n[1:2] if n[0]=='mul' else []
seen=set()
def walk(i):
 if i in seen:return
 seen.add(i)
 for j in deps(i):walk(j)
for o in outputs:walk(o)
uses=collections.Counter(j for i in seen for j in deps(i))
(s/'operand-uses.json').write_text(json.dumps([dict(output=j,node=o,operands=deps(o),uses=[uses[i] for i in deps(o)]) for j,o in enumerate(outputs)],indent=2)+'\n')
base=(s/'baseline/toeplitz_core.zig').read_text();prefix=base[:base.index('inline fn circuit')];suffix=base[base.index('pub inline fn forward(comptime'):]
def expr(i):
 n=nodes[i];return '0' if n[0]=='zero' else f'input[{n[1]}]' if n[0]=='input' else f'w{i}'
def emit(name,order,tie='lastuse',early=False):
 dest=s/name
 if dest.exists():shutil.rmtree(dest)
 shutil.copytree(s/'baseline',dest)
 body='inline fn circuit(comptime T: type, input: [16]T, key: @Vector(16, u8)) [16]T {\n'
 remaining=uses.copy();outnames={o:j for j,o in enumerate(outputs)}
 # Uses of final nodes are represented by their seeded output, never doubled.
 for i in order:
  n=nodes[i]
  if n[0] in ['zero','input']:continue
  if i in outnames:
   j=outnames[i];a,b=deps(i)
   if tie=='single' and uses[b]<uses[a] or tie=='first8' and j<8 and uses[b]<uses[a] or tie=='lastuse' and remaining[b]<remaining[a]:a,b=b,a
   rhs=f'xor3(T, {expr(a)}, {expr(b)}, (if (T == u8) key[{j}] else @as(T, @splat(key[{j}]))))'
   body+=f'    const out{j} = {rhs};\n'
  else:
   rhs=f'multiply(T, {expr(n[1])}, {n[2]})' if n[0]=='mul' else f'{expr(n[1])} ^ {expr(n[2])}'
   body+=f'    const w{i} = {rhs};\n'
  for j in deps(i):remaining[j]-=1
 body+='    return .{ '+', '.join(f'out{j}' for j in range(16))+' };\n}\n'
 (dest/'toeplitz_core.zig').write_text(prefix+body+suffix)
creation=sorted(seen-set(outputs))+outputs
emit('first8',creation,'first8');emit('single',creation,'single')
for outorder,label in [(outputs,'forward'),(outputs[::-1],'reverse'),([outputs[j] for i in range(8) for j in [i,i+8]],'paired'),([outputs[j] for i in range(7,-1,-1) for j in [i+8,i]],'paired-reverse')]:
 for reverse in [False,True]:
  order=[];visited=set()
  def visit(i):
   if i in visited:return
   visited.add(i)
   for j in deps(i)[::(-1 if reverse else 1)]:visit(j)
   order.append(i)
  for o in outorder:visit(o)
  emit('dfs-'+label+('-r' if reverse else ''),order)
print('Emitted first8, single and eight output/child DFS schedules.')
# Rebuild the same recursion with all six child computation orders. This changes
# node creation/emission order, never the equal-block identity or endpoints.
oldnodes,oldoutputs=nodes,outputs
class DAG:
 def __init__(self):self.nodes=[('zero',)]+[('input',i) for i in range(16)];self.cache={n:i for i,n in enumerate(self.nodes)}
 def node(self,n):
  if n not in self.cache:self.cache[n]=len(self.nodes);self.nodes.append(n)
  return self.cache[n]
 def xor(self,a,b):return 0 if a==b else b if not a else a if not b else self.node(('xor',min(a,b),max(a,b)))
 def prod(self,a,c):return 0 if not a or not c else a if c==1 else self.node(('mul',a,c))
def trans(d,t,x,perm):
 n=len(t)
 if n==1:return [d.prod(x[0],t[0][0])]
 m=n//2;a=[r[:m] for r in t[:m]]
 assert a==[r[m:] for r in t[m:]]
 mats=[a,[[a[i][j]^t[i][m+j] for j in range(m)] for i in range(m)],[[a[i][j]^t[m+i][j] for j in range(m)] for i in range(m)]]
 results={}
 for k in perm:
  xx=[d.xor(x[i],x[m+i]) for i in range(m)] if k==0 else x[m:] if k==1 else x[:m]
  results[k]=trans(d,mats[k],xx,perm)
 return [d.xor(results[0][i],results[1][i]) for i in range(m)]+[d.xor(results[0][i],results[2][i]) for i in range(m)]
def gf(a,b):
 out=0
 for _ in range(8):
  if b&1:out^=a
  a=((a<<1)^(0x1c3 if a&128 else 0))&255;b>>=1
 return out
def evaluate(nn,oo,x):
 v=[]
 for n in nn:v.append(0 if n[0]=='zero' else x[n[1]] if n[0]=='input' else v[n[1]]^v[n[2]] if n[0]=='xor' else gf(v[n[1]],n[2]))
 return [v[o] for o in oo]
for perm in itertools.permutations(range(3)):
 d=DAG();outputs=trans(d,p['matrix'],list(range(1,17)),perm);nodes=d.nodes
 for pos in range(16):
  for bit in range(8):
   x=[0]*16;x[pos]=1<<bit
   assert evaluate(nodes,outputs,x)==evaluate(oldnodes,oldoutputs,x)
 seen=set()
 for o in outputs:walk(o)
 uses=collections.Counter(j for i in seen for j in deps(i))
 emit('recursive-'+''.join('pqr'[i] for i in perm),sorted(seen-set(outputs))+outputs)
print('Emitted six exact-basis-validated recursive child permutations.')
