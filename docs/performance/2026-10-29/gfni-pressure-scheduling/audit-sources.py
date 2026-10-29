#!/usr/bin/env python3
"""Audit source-only experiments against exact v0.9.3 Git objects."""
import hashlib,json,pathlib,subprocess,sys
repo=pathlib.Path(sys.argv[1]).resolve();s=pathlib.Path(sys.argv[2]).resolve();base='567ab5e19531c2d746f6bfee489f58177933ea61'
files=subprocess.check_output(['git','-C',str(repo),'ls-tree','-r','--name-only',base,'src']).decode().splitlines()
expected={str(pathlib.Path(f).relative_to('src')):hashlib.sha256(subprocess.check_output(['git','-C',str(repo),'show',base+':'+f])).hexdigest() for f in files}
original=(s/'baseline/toeplitz_core.zig').read_text();start=original.index('inline fn circuit');end=original.index('pub inline fn forward(comptime')
manifest={}
for v in ['baseline','candidate']+sorted(json.loads((s/'schedules.json').read_text())):
 hashes={f:hashlib.sha256((s/v/f).read_bytes()).hexdigest() for f in expected}
 changes=[f for f in expected if hashes[f]!=expected[f]]
 if v in ['baseline','candidate']:assert changes==[],(v,changes)
 else:
  assert changes==['toeplitz_core.zig'],(v,changes)
  text=(s/v/'toeplitz_core.zig').read_text()
  assert text[:text.index('inline fn circuit')]==original[:start]
  assert text[text.index('pub inline fn forward(comptime'):]==original[end:]
  assert hashes['toeplitz_core.zig']==json.loads((s/'schedules.json').read_text())[v]['source_sha256']
 manifest[v]=dict(hashes=hashes,changed_source_files=changes,all_scales_sboxes_assembly_constraints_memory_clobbers_endpoints_unchanged=True)
(s/'source-audit.json').write_text(json.dumps(dict(base=base,variants=manifest),indent=2)+'\n')
print(f'Exact baseline/copy and {len(manifest)-2} schedules audited; only circuit statement order differs.')
