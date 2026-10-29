from pathlib import Path
import hashlib, struct, json
from gostcrypto.gostcipher.gost_34_12_2015 import GOST34122015Kuznechik
B=Path('/home/t3/mgm-profiles-review-20261029')
blob=bytearray(); cases=[]
def store(x):
 at=len(blob); blob.extend(x); return f'blob[{at}..][0..{len(x)}]'
def hx(x): return 'hex("'+x.hex()+'")'
def derive(label,n):
 return hashlib.shake_256(label.encode()).digest(n)
def fieldmul(x,y):
 # Schoolbook carryless full product, then polynomial long division.
 product=0
 for bit in range(128):
  if x>>bit&1: product ^= y<<bit
 mod=(1<<128)|(1<<7)|(1<<2)|(1<<1)|1
 for bit in range(254,127,-1):
  if product>>bit&1: product ^= mod<<(bit-128)
 return product
def oracle(key,nonce,aad,plain):
 c=GOST34122015Kuznechik(bytearray(key))
 def e(x): return bytes(c.encrypt(bytearray(x)))
 def count(seed,index,left):
  a,b=struct.unpack('>QQ',seed)
  if left: a=(a+index)&((1<<64)-1)
  else: b=(b+index)&((1<<64)-1)
  return struct.pack('>QQ',a,b)
 y=e(nonce); z=e(bytes([nonce[0]|128])+nonce[1:]); enc=bytearray()
 for i in range(0,len(plain),16): enc.extend(a^b for a,b in zip(plain[i:i+16],e(count(y,i//16,False))))
 blocks=[]
 for domain in (aad,bytes(enc)):
  blocks.extend(domain[i:i+16].ljust(16,b'\0') for i in range(0,len(domain),16))
 blocks.append(struct.pack('>QQ',8*len(aad),8*len(enc)))
 s=0
 for i,block in enumerate(blocks): s ^= fieldmul(int.from_bytes(e(count(z,i,True)),'big'),int.from_bytes(block,'big'))
 return bytes(enc),e(s.to_bytes(16,'big'))
lengths=[0,1,15,16,17,463,464,465,1023,1024,1025,2049]
for kind in ('raw','tlsl','tlss','espsn','espesn','macsn','macesn','ike','fragment'):
 for j,n in enumerate(lengths + ([1,16,17,1024,1025] if kind=='raw' else [])):
  if kind.startswith('tls') and n==0: continue
  label=f'review-v1-{kind}-{j}'; key=derive(label+'key',32); plain=derive(label+'plain',n)
  salt=derive(label+'salt',12); write_iv=derive(label+'write_iv',16)
  seq=int.from_bytes(derive(label+'seq',8),'big'); seq &= ((1<<42)-1) if kind=='tlss' else ((1<<64)-1)
  iv=derive(label+'iv',8); esp=derive(label+'esp',12 if kind.endswith('esn') else 8)
  extra=derive(label+'extra',[0,1,15,16,17,1007,1008,1009,1023,1024,1025,2049][j%12])
  head=derive(label+'head',28); tail=derive(label+'tail',8 if kind=='fragment' else 4)
  if kind=='raw': nonce=bytes([write_iv[0]&127])+write_iv[1:]; aad=b'' if j>=12 else extra or b'\x85'
  elif kind.startswith('tls'):
   nonce=bytearray(write_iv)
   for i,b in enumerate(seq.to_bytes(8,'big')): nonce[8+i] ^= b
   nonce[0]&=127; nonce=bytes(nonce); aad=b'\x17\x03\x03'+(n+16).to_bytes(2,'big')
  else:
   nonce=b'\0'+iv[5:]+salt
   if kind in ('ike','fragment'): aad=head+extra+tail
   elif kind.startswith('mac'): aad=esp+iv+plain
   else: aad=esp
  enc,tag=oracle(key,nonce,aad,b'' if kind.startswith('mac') else plain)
  expected=plain if kind.startswith('mac') else enc
  cases.append(f'.{{ .kind=.{kind}, .key={hx(key)}, .nonce={hx(nonce)}, .salt={hx(salt)}, .write_iv={hx(write_iv)}, .seq={seq}, .iv={hx(iv)}, .esp={store(esp)}, .head={hx(head)}, .tail={store(tail)}, .extra={store(extra)}, .aad={store(aad)}, .plain={store(plain)}, .enc={store(expected)}, .tag={hx(tag)} }}')
out='''const hex = @import("modes/test_helpers.zig").hex;
pub const blob = @embedFile("review_oracle.bin");
pub const Kind = enum { raw,tlsl,tlss,espsn,espesn,macsn,macesn,ike,fragment };
pub const Case = struct { kind: Kind, key: [32]u8, nonce: [16]u8, salt: [12]u8, write_iv: [16]u8, seq: u64, iv: [8]u8, esp: []const u8, head: [28]u8, tail: []const u8, extra: []const u8, aad: []const u8, plain: []const u8, enc: []const u8, tag: [16]u8 };
pub const cases = blk: { @setEvalBranchQuota(300000); break :blk [_]Case{\n'''+',\n'.join(cases)+'\n}; };\n'
for dest in ('branch','integration'):
 (B/dest/'src/review_vectors.zig').write_text(out)
 (B/dest/'src/review_oracle.bin').write_bytes(blob)
print(json.dumps(dict(cases=len(cases),blob_bytes=len(blob),sha256=hashlib.sha256(blob).hexdigest())))
