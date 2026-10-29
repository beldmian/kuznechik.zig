#!/usr/bin/env python3
"""Verify every production baseline file against the released object and isolation."""
import hashlib,json,pathlib,subprocess,sys
repo=pathlib.Path(sys.argv[1]).resolve();stage=pathlib.Path(sys.argv[2]).resolve();base='a518ff4aed72f1d9cfe8b923944ca68ec39b2d0f'
variants=json.loads((stage/'variants.json').read_text());files=subprocess.check_output(['git','-C',str(repo),'ls-tree','-r','--name-only',base,'src'],text=True).splitlines()
hashes={};diffs={}
for f in files:
 rel=pathlib.Path(f).relative_to('src');expected=subprocess.check_output(['git','-C',str(repo),'show',base+':'+f])
 assert expected==(stage/'baseline'/rel).read_bytes(),f
 for n in ['control']+list(variants):
  actual=(stage/n/rel).read_bytes()
  if actual!=expected:diffs.setdefault(n,[]).append(str(rel))
for n,dd in diffs.items():assert dd==['hybrid.zig'],(n,dd)
for n in variants:assert n in diffs
for p in sorted(stage.rglob('*.zig')):hashes[str(p.relative_to(stage))]=hashlib.sha256(p.read_bytes()).hexdigest()
(stage/'measured-source-hashes.json').write_text(json.dumps(dict(baseline=base,differences=diffs,files=hashes),indent=2)+'\n')
print('Released baseline verified; only hybrid.zig differs in each generated variant; exact control verified.')
