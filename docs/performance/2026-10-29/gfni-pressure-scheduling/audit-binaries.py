#!/usr/bin/env python3
"""Audit timed binary disassemblies, including unchanged portable instruction gate."""
import gzip,hashlib,json,pathlib,re,sys
s=pathlib.Path(sys.argv[1]);out={}
for p in sorted(s.glob('*-binary.s.gz')):
 text=gzip.decompress(p.read_bytes()).decode();assert 'file format elf64-x86-64' in text,p
 labels=re.findall(r'(?m)^([0-9a-f]+) <([^>]+)>:',text)
 public=[dict(address=a,symbol=n) for a,n in labels if 'pairs.apply' in n or 'pairs.run' in n or 'toeplitz.' in n or 'Cipher.encryptBlocks' in n or 'Cipher.decryptBlocks' in n]
 assert public,(p,'missing actual public call wrappers')
 gfni=len(re.findall(r'\bvgf2p8\w*\b',text));wide=len(re.findall(r'\bzmm\d+\b',text))
 if p.name.startswith('portable-'):assert gfni==wide==0,(p,gfni,wide)
 else:assert gfni>0 and wide>0,p
 out[p.name]=dict(compressed_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),disassembly_sha256=hashlib.sha256(text.encode()).hexdigest(),gfni_instructions=gfni,zmm_mentions=wide,public_symbols=public)
assert len(out)==10,(len(out),sorted(out))
(s/'binary-audit.json').write_text(json.dumps(out,indent=2)+'\n');print('10 actual timed binary disassemblies audited; 3 portable binaries contain no GFNI/ZMM instructions.')
