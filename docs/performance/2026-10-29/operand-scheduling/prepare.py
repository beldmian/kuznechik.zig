#!/usr/bin/env python3
"""Derive/check the 70-map graph, select tied operands and extract v0.8.1.

No checkout is created. No working source is changed. Python standard library.
"""
import collections, hashlib, io, json, pathlib, random, shutil, subprocess, sys, tarfile
repo, stage = map(lambda s: pathlib.Path(s).resolve(), sys.argv[1:3])
base = '40f77f43fd964a8ac528bf686ce7c1cda859424d'  # Released v0.8.1, not the historical 75-map baseline.
proof = json.loads((repo/'docs/performance/toeplitz-proof.json').read_text())
C = [148,32,133,16,194,192,1,251,1,192,194,16,133,32,148,1]
def gf(a,b):
    out = 0
    for _ in range(8):
        if b&1: out ^= a
        a = ((a<<1) ^ (0x1c3 if a&128 else 0)) & 255
        b >>= 1
    return out
M = [[gf(a,b) for b in range(256)] for a in range(256)]
def inv(a):
    assert a
    return M[a].index(1)
def xor(xs):
    out=0
    for x in xs: out ^= x
    return out
def linear(x, inverse=False):
    x=list(x)
    for _ in range(16):
        if inverse: x=x[1:]+[x[0]^xor(M[C[i]][x[i+1]] for i in range(15))]
        else: x=[xor(M[c][v] for c,v in zip(C,x))]+x[:-1]
    return x
L=list(map(list,zip(*(linear([int(i==j) for i in range(16)]) for j in range(16)))))
# A scaled circulant requires all wrap ratios t[d+16]/t[d] to agree.
t0=proof['matrix']
wrap=[M[t0[d+16][0]][inv(t0[0][-d])] for d in range(-15,0)]
assert len(set(wrap))>1
# Compute the characteristic polynomial's actual field roots, not an assumption.
poly=list(reversed([1]+C))  # ascending coefficients of z^16+C0*z^15+...+C15
roots=[]
for x in range(256):
    p=0
    for c in reversed(poly): p=M[p][x]^c
    if p==0: roots.append(x)
assert len(roots)==16
class DAG:
    def __init__(self):
        self.nodes=[('zero',)]+[('input',i) for i in range(16)]
        self.cache={n:i for i,n in enumerate(self.nodes)}
    def node(self,t):
        if t not in self.cache:
            self.cache[t]=len(self.nodes);self.nodes.append(t)
        return self.cache[t]
    def xor(self,a,b):
        if a==b:return 0
        if not a:return b
        if not b:return a
        return self.node(('xor',min(a,b),max(a,b)))
    def prod(self,a,c):
        if not a or not c:return 0
        if c==1:return a
        return self.node(('mul',a,c))
    def evaluate(self,outputs,x):
        v=[]
        for n in self.nodes:
            if n[0]=='zero':v.append(0)
            elif n[0]=='input':v.append(x[n[1]])
            elif n[0]=='xor':v.append(v[n[1]]^v[n[2]])
            else:v.append(M[v[n[1]]][n[2]])
        return [v[o] for o in outputs]
def transform(d,t,x):
    n=len(t)
    if n==1:return [d.prod(x[0],t[0][0])]
    m=n//2
    a=[r[:m] for r in t[:m]]
    # This equal-block invariant is weaker than being Toeplitz, and suffices.
    assert a==[r[m:] for r in t[m:]]
    b=[[a[i][j]^t[i][m+j] for j in range(m)] for i in range(m)]
    c=[[a[i][j]^t[m+i][j] for j in range(m)] for i in range(m)]
    p=transform(d,a,[d.xor(x[i],x[m+i]) for i in range(m)])
    q=transform(d,b,x[m:]);r=transform(d,c,x[:m])
    return [d.xor(p[i],q[i]) for i in range(m)]+[d.xor(p[i],r[i]) for i in range(m)]
def stats(d,outputs):
    seen=set()
    def walk(i):
        if i in seen:return
        seen.add(i);n=d.nodes[i]
        for j in n[1:] if n[0]=='xor' else n[1:2] if n[0]=='mul' else []:walk(j)
    for o in outputs:walk(o)
    depth={};used=collections.Counter(outputs)
    for i in seen:
        n=d.nodes[i]
        used.update(n[1:] if n[0]=='xor' else n[1:2] if n[0]=='mul' else [])
    live=set();peak=0
    for i in sorted(seen):
        n=d.nodes[i]
        if n[0]=='zero':continue
        depth[i]=0 if n[0]=='input' else depth[n[1]]+3 if n[0]=='mul' else max(depth[n[1]],depth[n[2]])+1
        live.add(i);peak=max(peak,len(live))
        for j in n[1:] if n[0]=='xor' else n[1:2] if n[0]=='mul' else []:
            used[j]-=1
            if not used[j]:live.discard(j)
    return dict(gfni=sum(d.nodes[i][0]=='mul' for i in seen),xor=sum(d.nodes[i][0]=='xor' for i in seen),peak_live_values=peak,modeled_depth_cycles=max(depth[o] for o in outputs)),seen
stage.mkdir(parents=True,exist_ok=True)
archive=subprocess.check_output(['git','-C',str(repo),'archive',base,'src'])
for name in ['baseline','candidate']:
    dest=stage/name
    if dest.exists():shutil.rmtree(dest)
    dest.mkdir()
    with tarfile.open(fileobj=io.BytesIO(archive)) as tf:
        for m in tf.getmembers():
            if not m.isfile():continue
            p=dest/pathlib.PurePosixPath(m.name).relative_to('src')
            p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(tf.extractfile(m).read())
q=[21,138,187,232];gamma=152
if len(sys.argv)>3:
    q=list(map(int,sys.argv[3].split(',')));gamma=int(sys.argv[4])
s=[1]*16
for i in range(16):
    for bit in range(4):
        if i&(1<<bit):s[i]=M[s[i]][q[bit]]
rs=[M[r][v] for r,v in zip(proof['row_scale'],s)]
cs=[M[gamma][M[c][inv(v)]] for c,v in zip(proof['column_scale'],s)]
a=collections.Counter([inv(v) for v in rs]+cs).most_common(1)[0][0]
rs=[M[a][v] for v in rs];cs=[M[inv(a)][v] for v in cs]
t=[[M[rs[i]][M[L[i][j]][cs[j]]] for j in range(16)] for i in range(16)]
d=DAG();outputs=transform(d,t,list(range(1,17)));counts,seen=stats(d,outputs)
for pos in range(16):
    for value in range(256):
        raw=[0]*16;raw[pos]=value
        for inverse in [False,True]:
            x=raw[::-1] if inverse else raw
            y=[M[inv(r)][v] for r,v in zip(rs,d.evaluate(outputs,[M[inv(c)][v] for c,v in zip(cs,x)]))]
            if inverse:y=y[::-1]
            assert y==linear(raw,inverse)
# Key injection is independently checked against dense matrix multiplication.
rng=random.Random(0x850070)
for _ in range(1024):
    x=[rng.randrange(256) for _ in range(16)];k=[rng.randrange(256) for _ in range(16)]
    assert [v^b for v,b in zip(d.evaluate(outputs,x),k)]==[xor(M[a][b] for a,b in zip(row,x))^kk for row,kk in zip(t,k)]
p=stage/'candidate/toeplitz_core.zig'
old=p.read_text();prefix=old[:old.index('pub const row_scale')]
prefix=prefix.replace('Toeplitz circuit:75',f'recursive equal-block circuit:{counts["gfni"]}').replace('recursive equal-block circuit:70',f'recursive equal-block circuit:{counts["gfni"]}').replace('docs/performance/reproduce-toeplitz.py','docs/performance/2026-10-29/operand-scheduling/prepare.py').replace('docs/performance/2026-10-29/bitwise-normalization/prepare.py','docs/performance/2026-10-29/operand-scheduling/prepare.py')
for name,vals in [('row_scale',rs),('column_scale',cs),('row_inverse',list(map(inv,rs))),('column_inverse',list(map(inv,cs)))]:
    prefix+=f'pub const {name} = [16]u8{{ '+', '.join(map(str,vals))+' };\n'
prefix+=old[old.index('pub inline fn multiplyConstant'):old.index('inline fn circuit')]
def expr(i):
    n=d.nodes[i]
    if n[0]=='zero':return '0'
    if n[0]=='input':return f'input[{n[1]}]'
    return f'w{i}'
body='inline fn circuit(comptime T: type, input: [16]T, key: @Vector(16, u8)) [16]T {\n'
# Last output XORs become seeded xor3 exactly as in the released kernel.
for i in sorted(seen-set(outputs)):
    n=d.nodes[i]
    if n[0] in ['input','zero']:continue
    rhs=f'multiply(T, {expr(n[1])}, {n[2]})' if n[0]=='mul' else f'{expr(n[1])} ^ {expr(n[2])}'
    body+=f'    const w{i} = {rhs};\n'
# vpternlogd overwrites its first operand. Prefer the one-use output limb
# over a limb still needed by a later output. Leave ties in DAG order.
# XOR is commutative in both scalar and vector instantiations.
uses = collections.Counter()
# All intermediate nodes have already been emitted; only outputs remain.
for i in outputs:
    uses.update(d.nodes[i][1:])
outs=[]
selected_operands=[]
for j,i in enumerate(outputs):
    n=d.nodes[i];assert n[0]=='xor'
    left, right = sorted(n[1:], key=lambda operand: uses[operand])
    selected_operands.append([left, right])
    outs.append(f'xor3(T, {expr(left)}, {expr(right)}, (if (T == u8) key[{j}] else @as(T, @splat(key[{j}]))))')
    uses.subtract(n[1:])
body+='    return .{ '+', '.join(outs)+' };\n}\n'
p.write_text(prefix+body+old[old.index('pub inline fn forward(comptime'):])
p=stage/'candidate/toeplitz.zig'
p.write_text(p.read_text().replace('//! Sixty-four blocks with a diagonally encoded Toeplitz linear layer.','//! Sixty-four blocks with a diagonally encoded recursive linear layer.').replace('//! L = Drow^-1 * T * Dcolumn^-1. Position-specific S-boxes absorb the','//! L = Drow^-1 * T * Dcolumn^-1; T has equal recursive diagonal blocks.\n//! Position-specific S-boxes absorb the'))
(stage/'proof.json').write_text(json.dumps(dict(base=base,q=q,gamma=gamma,split=a,row_scale=rs,column_scale=cs,matrix=t,nodes=d.nodes,outputs=outputs,stats=counts,output_operand_policy='fewest remaining uses, stable ties',output_operands=selected_operands,characteristic_roots=roots,scaled_circulant_wrap_ratios=wrap,validated_byte_basis_per_direction=4096,seeded_random_vectors=1024),indent=2)+'\n')
hashes={name:{str(p.relative_to(stage/name)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((stage/name).rglob('*')) if p.is_file()} for name in ['baseline','candidate']}
(stage/'source-hashes.json').write_text(json.dumps(hashes,indent=2)+'\n')
print(json.dumps(dict(q=q,gamma=gamma,stats=counts,output_operand_policy='fewest remaining uses, stable ties',output_operands=selected_operands,characteristic_roots=roots,scaled_circulant_wrap_ratios=wrap)))
