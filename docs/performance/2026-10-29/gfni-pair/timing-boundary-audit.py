#!/usr/bin/env python3
import re,pathlib,json,sys
out=[]
for path in sys.argv[1:]:
 s=pathlib.Path(path).read_text()
 for m in re.finditer(r'\s*\.type\s+([^,]+blocks[^,]*),@function',s):
  body=s[m.end():s.find('\n\t.size',m.end())]
  clock=body.find('os.linux.vdso_clock_gettime');gfni=body.find('vgf2p8')
  assert clock>=0 and gfni>clock,(path,m[1])
  # Whole copies of Cipher into the workload frame precede timing; GFNI
  # field/key conversion starts after clock reads, within the sample body.
  out.append({'file':str(path),'function':m[1],'first_clock_offset':clock,'first_gfni_offset':gfni,'gfni_before_first_clock':False})
assert len(out)==4,len(out)
print(json.dumps(out,indent=2))
