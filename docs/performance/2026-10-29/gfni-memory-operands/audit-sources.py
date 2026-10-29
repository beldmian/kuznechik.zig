#!/usr/bin/env python3
import hashlib,json,pathlib,subprocess,sys
repo=pathlib.Path(sys.argv[1]).resolve();s=pathlib.Path(sys.argv[2]).resolve();h=lambda b:hashlib.sha256(b).hexdigest()
base=subprocess.check_output(['git','-C',str(repo),'rev-parse','cd9c731']).decode().strip();out={}
files=subprocess.check_output(['git','-C',str(repo),'ls-tree','-r','--name-only',base,'src']).decode().splitlines()
for name in ['baseline','candidate','explicit-clobber','explicit-read']:
 changed=[]; hashes={}
 for f in files:
  rel=str(pathlib.Path(f).relative_to('src'));old=subprocess.check_output(['git','-C',str(repo),'show',base+':'+f]);new=(s/name/rel).read_bytes();hashes[rel]=h(new)
  if new!=old:
   assert rel=='toeplitz_core.zig', (name,rel)
   prefix=old.index(b'    const code = comptime std.fmt.comptimePrint(');last=old.index(b'\n}',prefix)
   newlast=new.index(b'\n}',prefix)
   assert new[:prefix]==old[:prefix] and new[newlast:]==old[last:],name
   changed.append(rel)
 assert changed==([] if name in ['baseline','candidate'] else ['toeplitz_core.zig']),name
 out[name]=dict(changed=changed,sha256=hashes)
# No library edit in the implementation checkout is needed for this rejection.
assert subprocess.check_output(['git','-C',str(repo),'diff',base,'--','src'])==b''
(s/'independent-source-audit.json').write_text(json.dumps(dict(base=base,working_library_unchanged=True,fixtures=out),indent=2)+'\n')
print('All released source identities and helper-only fixture differences verified.')
