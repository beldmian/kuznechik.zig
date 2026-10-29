#!/usr/bin/env python3
"""Bounded ready-list scheduling: retain the DAG and fixed first-eight XOR policy.
No uniform recursive orders or DFS permutations. Compiler output, then public APIs,
are selection criteria; the liveness proxy is explicitly not a hardware proof.
"""
import collections,hashlib,json,pathlib,random,shutil,sys
s=pathlib.Path(sys.argv[1]);p=json.loads((s/'proof.json').read_text());nodes=p['nodes'];outputs=p['outputs'];outs={o:j for j,o in enumerate(outputs)}
def deps(i):
 n=nodes[i];return n[1:] if n[0]=='xor' else n[1:2] if n[0]=='mul' else []
seen=set()
def walk(i):
 if i in seen:return
 seen.add(i)
 for j in deps(i):walk(j)
for o in outputs:walk(o)
used=collections.Counter(j for i in seen for j in deps(i));children={i:[] for i in seen}
for i in seen:
 for j in deps(i):children[j].append(i)
critical={}
for i in sorted(seen,reverse=True):critical[i]=(3 if nodes[i][0]=='mul' else 1)+max([critical[c] for c in children[i]] or [0])
ancestors={}
for i in sorted(seen):ancestors[i]={i}.union(*(ancestors[j] for j in deps(i)))
base=(s/'baseline/toeplitz_core.zig').read_text();prefix=base[:base.index('inline fn circuit')];suffix=base[base.index('pub inline fn forward(comptime'):]
creation=[i for i in sorted(seen) if i not in outs and nodes[i][0] not in ['input','zero']]+outputs
params=[]
# Strong proximity weight keeps some of the compiler-friendly creation locality;
# the other policies let release/criticality/branch priorities choose nonuniformly.
for k,(release,critical_w,proximity,focus,output_w,noise) in enumerate([
 (8,0,0,0,0,0),(8,1,0,0,0,0),(4,3,0,0,0,0),(12,1,.04,0,0,0),
 (8,1,.15,0,0,0),(8,1,.5,0,0,0),(4,1,1,0,0,0),(8,1,2,0,0,0),
 (8,1,.15,1,0,0),(8,1,.15,2,0,0),(8,1,.15,3,0,0),(8,1,.15,4,0,0),
 (12,1,.15,0,12,0),(8,1,.5,0,-12,0),(8,1,.15,1,8,0),(8,1,.15,3,8,0),
 (8,1,.15,0,0,2),(8,1,.15,0,0,4),(8,1,.5,0,0,2),(8,1,.5,0,0,4),
 (12,2,.15,2,4,2),(12,2,.5,4,4,2),(8,4,.15,1,4,2),(8,4,.5,3,4,2)]):
 params.append(dict(name=f'ready{k:02}',release=release,critical=critical_w,proximity=proximity,focus=focus,output=output_w,noise=noise,seed=902900+k))
manifest={};generated={};duplicates={}
def evaluate(order,x,key):
 v={i:0 if nodes[i][0]=='zero' else x[nodes[i][1]] for i in seen if nodes[i][0] in ['zero','input']}
 for i in order:
  n=nodes[i];v[i]=v[n[1]]^v[n[2]] if n[0]=='xor' else gf(v[n[1]],n[2])
 return [v[o]^key[j] for j,o in enumerate(outputs)]
def gf(a,b):
 out=0
 for _ in range(8):
  if b&1:out^=a
  a=((a<<1)^(0x1c3 if a&128 else 0))&255;b>>=1
 return out
def expr(i):return f'input[{nodes[i][1]}]' if nodes[i][0]=='input' else '0' if nodes[i][0]=='zero' else f'w{i}'
mul_table=[[gf(a,b) for b in range(256)] for a in range(256)]
def gf(a,b):return mul_table[a][b]
# Existing all-16 output remaining-use policy equals the released first-eight
# swaps with stable remaining ties. Keep these exact operands for every schedule.
operands=p['output_operands']
(s/'policies.json').write_text(json.dumps(params,indent=2)+'\n')
for config in params:
 rng=random.Random(config['seed']);remaining=used.copy();done={i for i in seen if nodes[i][0] in ['input','zero']};live=done-{0};order=[];trace=[];peak=0
 priorities=[outputs,outputs[::-1],[outputs[j] for i in range(8) for j in (i,i+8)],[outputs[j] for i in range(7,-1,-1) for j in (i+8,i)]]
 outorder=priorities[(config['focus']-1)%4]
 jitter={i:rng.uniform(-1,1)*config['noise'] for i in seen}
 while len(done)<len(seen):
  ready=[i for i in sorted(seen-done) if all(j in done for j in deps(i))]
  focus=next((o for o in outorder if o not in done),None)
  def score(i):
   releases=sum(remaining[j]==1 for j in deps(i));delta=1-releases
   locality=creation.index(i)-min(creation.index(j) for j in seen-done)
   return (config['release']*(-delta)+config['critical']*critical[i]-config['proximity']*locality+(10 if config['focus'] and i in ancestors[focus] else 0)+(config['output'] if i in outs else 0)+jitter[i],-i)
  i=max(ready,key=score);done.add(i);order.append(i);live.add(i)
  for j in deps(i):
   remaining[j]-=1
   if not remaining[j]:live.discard(j)
  # Retain final output vectors to return; one 128-bit seed plus matrix pointer
  # and 10 public round keys are accounted separately, as are constants.
  peak=max(peak,len(live));trace.append(len(live))
 body='inline fn circuit(comptime T: type, input: [16]T, key: @Vector(16, u8)) [16]T {\n'
 for i in order:
  n=nodes[i]
  if i in outs:
   j=outs[i];a,b=operands[j]
   rhs=f'xor3(T, {expr(a)}, {expr(b)}, (if (T == u8) key[{j}] else @as(T, @splat(key[{j}]))))'
  else:rhs=f'multiply(T, {expr(n[1])}, {n[2]})' if n[0]=='mul' else f'{expr(n[1])} ^ {expr(n[2])}'
  body+=f'    const w{i} = {rhs};\n'
 body+='    return .{ '+', '.join(f'w{o}' for o in outputs)+' };\n}\n'
 text=prefix+body+suffix;digest=hashlib.sha256(text.encode()).hexdigest()
 if digest in generated:
  duplicates[config['name']]=generated[digest]
  (s/'duplicate-policies.json').write_text(json.dumps(duplicates,indent=2)+'\n')
  continue
 generated[digest]=config['name'];dest=s/config['name'];shutil.copytree(s/'baseline',dest,dirs_exist_ok=True);(dest/'toeplitz_core.zig').write_text(text)
 # Every 128 binary and 4096 byte basis at normalized DAG level; reverse too.
 # Both directed actual L/scaled basis identities checked by prepare.py.
 for pos in range(16):
  for value in range(256):
   x=[0]*16;x[pos]=value
   assert evaluate(order,x,[0]*16)==evaluate(creation,x,[0]*16)
 rr=random.Random(902970)
 for _ in range(1024):
  x=[rr.randrange(256) for _ in range(16)];key=[rr.randrange(256) for _ in range(16)]
  assert evaluate(order,x,key)==[__import__('functools').reduce(int.__xor__,(gf(a,b) for a,b in zip(row,x)),key[j]) for j,row in enumerate(p['matrix'])]
  assert evaluate(order,x[::-1],key[::-1])[::-1]==evaluate(creation,x[::-1],key[::-1])[::-1]
 manifest[config['name']]=dict(parameters=config,order=order,source_sha256=digest,peak_live_graph_values=peak,trace=trace,gfni=sum(nodes[i][0]=='mul' for i in order),xor=sum(nodes[i][0]=='xor' for i in order),byte_basis_checks=4096,binary_basis_included=128,seeded_dense_checks=1024,inputs_initially_live=16,final_outputs_retained=16,additional_cipher_context='one 128-bit seed; ten round key vectors; matrix pointer; S-box tables and endpoint constants, whose allocation/rematerialization is compiler-dependent; no hardware-register-bound claim')
 (s/'schedules.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print(config['name'],peak,digest,flush=True)
