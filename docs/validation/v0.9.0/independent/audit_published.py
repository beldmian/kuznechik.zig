from pathlib import Path
import re,json,hashlib
B=Path('/home/t3/mgm-profiles-review-20261029')
# Reuse only this review's own schoolbook/long-division MGM oracle.
s=(B/'evidence/generate_review.py').read_text(); exec(s.split('lengths=')[0])
S=B/'branch'; rfc=(B/'evidence/rfc9367.txt').read_text()
rfc=rfc[:rfc.rindex('A.2.  Example 2')]
sections=rfc.split('   Record payload protection:')[1:]
assert len(sections)==17
vectors=(S/'src/modes/mgm_profiles_vectors.zig').read_text(); blob=(S/'src/modes/mgm_profiles_oracle.bin').read_bytes()
vector_lines=[x for x in vectors.splitlines() if '.sequence =' in x]
assert len(vector_lines)==17

def rows(section,label):
 tail=section.split(label+':',1)[1]
 found=[]
 for line in tail.splitlines()[1:]:
  if not line.strip(): break
  if line.strip()=='[...]': continue
  addr,hexbytes=line.strip().split(':',1)
  found.append((int(addr,16),bytes.fromhex(hexbytes)))
 return found

def joined(section,label):
 out=bytearray()
 for offset,data in rows(section,label):
  assert offset==len(out);out.extend(data)
 return bytes(out)

total=0; elided=0; complete_tag_count=0
for index,(section,line) in enumerate(zip(sections,vector_lines)):
 seq=int(re.search(r'\.sequence = (\d+)',line)[1]); key=bytes.fromhex(re.search(r'\.key = hex\("([a-f0-9]+)"',line)[1])
 nonce=joined(section,'nonce'); aad=joined(section,'additional_data')
 count=int.from_bytes(aad[3:],'big')-16
 plain=bytearray(count); covered=set()
 for offset,data in rows(section,'TLSInnerPlaintext'):
  assert offset+len(data)<=count;plain[offset:offset+len(data)]=data;covered.update(range(offset,offset+len(data)))
 if len(covered)!=count:
  # Primary text preceding these records explicitly specifies 1024 zero
  # content octets and 15360 padding octets, with type23 at offset1024.
  assert count==16385 and plain[1024]==23 and plain==bytes(1024)+b'\x17'+bytes(15360);elided+=1
 for name,expected in [('plaintext',bytes(plain))]:
  off,n=map(int,re.search(r'\.'+name+r' = blob\[(\d+)\.\.\]\[0\.\.(\d+)\]',line).groups()); assert blob[off:off+n]==expected
 enc,tag=oracle(key,nonce,aad,bytes(plain));wire=aad+enc+tag
 off,n=map(int,re.search(r'\.ciphertext_tag = blob\[(\d+)\.\.\]\[0\.\.(\d+)\]',line).groups()); assert blob[off:off+n]==enc+tag
 wire_covered=set()
 for offset,data in rows(section,'TLSCiphertext'):
  assert wire[offset:offset+len(data)]==data; total+=len(data);wire_covered.update(range(offset,offset+len(data)))
 assert set(range(len(wire)-16,len(wire)))<=wire_covered;complete_tag_count+=1
 # Also compare duplicated compact encrypted_record fields, including both
 # ends of explicitly omitted ranges, rather than only their address dump.
 compact=section.split('encrypted_record:',1)[1].split('\n\n',1)[0]
 compact=''.join(compact.split()); fragments=compact.split('[...]')
 assert len(fragments)<=2
 if len(fragments)==1: assert bytes.fromhex(fragments[0])==enc+tag
 else:
  assert (enc+tag).startswith(bytes.fromhex(fragments[0])); assert (enc+tag).endswith(bytes.fromhex(fragments[1]))
 print(f'TLS record {index}: full independent output and every primary dump/compact cipher byte match, tag16 covered')
assert elided==8
rfc=(B/'evidence/rfc9227.txt').read_text()
for num in (1,2,5,6):
 section=rfc.split(f'   {num}.  ENCR_',1)[1]
 def field(name):
  header,tail=section.split('      '+name+' [',1)[1].split(']:\n',1)
  lines=[]
  for row in tail.splitlines():
   if not re.fullmatch(r'          [0-9a-f ]+',row): break
   lines.append(row)
  data=bytes.fromhex(''.join(lines))
  assert len(data)==int(header);return data
 key,nonce,aad,plain,expected,tag=map(field,('K_msg','nonce','AAD','plaintext','ciphertext','ESP ICV'))
 enc,full=oracle(key,nonce,aad,plain)
 assert enc==expected and full[:12]==tag
 print(f'ESP example {num}: full primary ciphertext and ICV match independent oracle')
print(json.dumps(dict(tls_records=17,published_tls_wire_dump_bytes=total,complete_tls_tags=complete_tag_count,elided_long_plaintexts=elided,esp_examples=4)))
