#!/usr/bin/env python3
import gzip,hashlib,json,pathlib,struct,tarfile
s=pathlib.Path('/home/user/kuz-gfni-memory'); files=[]
# Preserve complete timed executable readonly pools and their ELF addresses.
sections={}
for binary in sorted(s.glob('pairs-*')):
 if binary.suffix or not binary.is_file():continue
 data=binary.read_bytes();assert data[:5]==b'\x7fELF\x02'
 shoff=struct.unpack_from('<Q',data,40)[0]; entsize,num,names=struct.unpack_from('<HHH',data,58)
 hdr=[struct.unpack_from('<IIQQQQIIQQ',data,shoff+i*entsize) for i in range(num)]
 shstr=data[hdr[names][4]:hdr[names][4]+hdr[names][5]]
 for h in hdr:
  name=shstr[h[0]:].split(b'\0',1)[0].decode()
  if name=='.rodata':
   raw=data[h[4]:h[4]+h[5]]
   (s/(binary.name+'.rodata.gz')).write_bytes(gzip.compress(raw,mtime=0))
   sections[binary.name]=dict(binary_sha256=hashlib.sha256(data).hexdigest(),address=h[3],bytes=h[5],rodata_sha256=hashlib.sha256(raw).hexdigest())
(s/'timed-rodata.json').write_text(json.dumps(sections,indent=2)+'\n')
for p in sorted(s.rglob('*')):
 if not p.is_file() or p.name=='vm-artifacts.sha256.json':continue
 if p.parent==s and ((p.name.startswith('pairs-') and p.suffix=='') or p.name.endswith('-aarch64')):continue
 files.append(p)
manifest={str(p.relative_to(s)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
(s/'vm-artifacts.sha256.json').write_text(json.dumps(manifest,indent=2)+'\n')
with tarfile.open('/home/user/gfni-memory-results.tar.gz','w:gz') as tf:
 for p in files+[s/'vm-artifacts.sha256.json']:tf.add(p,arcname=str(p.relative_to(s)))
print(hashlib.sha256(pathlib.Path('/home/user/gfni-memory-results.tar.gz').read_bytes()).hexdigest(), 'gfni-memory-results.tar.gz')
