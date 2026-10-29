import json,random
from pathlib import Path
from gostcrypto.gostcipher.gost_34_12_2015 import GOST34122015Kuznechik
r=random.Random(0x725391899337)
def rand(n):return r.randbytes(n)
def enc(k,p):return bytes(GOST34122015Kuznechik(bytearray(k)).encrypt(bytearray(p)))
def x(a,b):return bytes(c^d for c,d in zip(a,b))
def dbl(b):
 v=int.from_bytes(b,'big');return ((v<<1 ^ (0x87 if v>>127 else 0))&((1<<128)-1)).to_bytes(16,'big')
def mac(k,m):
 k1=dbl(enc(k,bytes(16)));k2=dbl(k1)
 if m and len(m)%16==0:last=x(m[-16:],k1); prior=m[:-16]
 else:
  n=len(m)%16; prior=m[:-n] if n else m;tail=m[-n:] if n else b'';last=x(tail+b'\x80'+bytes(15-n),k2)
 state=bytes(16)
 for i in range(0,len(prior),16):state=enc(k,x(state,prior[i:i+16]))
 return enc(k,x(state,last))
def stream(k,n,m,sec):
 out=bytearray(m)
 for i in range(0,len(m),16):
  if sec and i and i%sec==0:k=enc(k,bytes(range(128,144)))+enc(k,bytes(range(144,160)))
  gamma=enc(k,n+(i//16).to_bytes(8,'big'))
  out[i:i+16]=x(m[i:i+16],gamma)
 return bytes(out)
cases=[]
for kind,secs in [('kexp',[0]),('password',[48,80,1008,1040,4112]),('tls',[4096])]:
 for sec in secs:
  lengths=[0,2,14,18,47,48,49,79,80,81,1006,1010,1038,1040,1041,1042,2047,2048,2049,4110,4112,4113,5009]
  for n in lengths:
   ke,km,iv,m=rand(32),rand(32),rand(8),rand(n);seq=r.getrandbits(64);typ=r.randrange(256);ver=rand(2)
   prefix=iv if kind=='kexp' else b'';nonce=iv
   if kind=='tls':
    prefix=seq.to_bytes(8,'big')+bytes([typ])+ver+n.to_bytes(2,'big');nonce=((int.from_bytes(iv,'big')+seq)%(1<<64)).to_bytes(8,'big')
   ct=stream(ke,nonce,m+mac(km,prefix+m),sec)
   cases.append(dict(kind=kind,section=sec,enc=ke.hex(),mac=km.hex(),iv=iv.hex(),sequence=seq,content_type=typ,version=ver.hex(),plain=m.hex(),cipher=ct.hex()))
Path(__file__).with_name('new-composition.json').write_text(json.dumps(cases))
print('new independent composition cases:',len(cases))
