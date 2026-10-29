#!/usr/bin/env python3
"""Source-only snapshots pinned to v0.9.1; no checkout, API or dispatch changes."""
import hashlib, itertools, json, pathlib, shutil, subprocess, sys
BASE='a518ff4aed72f1d9cfe8b923944ca68ec39b2d0f'
repo=pathlib.Path(sys.argv[1]).resolve(); stage=pathlib.Path(sys.argv[2]).resolve();stage.mkdir(parents=True,exist_ok=True)
receipt=pathlib.Path(__file__).resolve().parent
files=subprocess.check_output(['git','-C',str(repo),'ls-tree','-r','--name-only',BASE,'src'],text=True).splitlines()
for f in files:
 p=stage/'baseline'/pathlib.Path(f).relative_to('src');p.parent.mkdir(parents=True,exist_ok=True)
 p.write_bytes(subprocess.check_output(['git','-C',str(repo),'show',BASE+':'+f]))
assert subprocess.check_output(['git','-C',str(repo),'rev-parse','v0.9.1^{}'],text=True).strip()==BASE
src=(stage/'baseline/hybrid.zig').read_text()
# Families intentionally cover cheap low-byte extractions, expensive high bytes,
# word boundaries, contiguous spans and spaced columns. No width/group-count search.
sets={
 'prefix': [0,1,2,3,4], 'suffix':[11,12,13,14,15],
 'high_prefix':[8,9,10,11,12], 'low_suffix':[3,4,5,6,7],
 'edge_mix':[0,1,7,8,15], 'boundary':[0,6,7,8,9],
 'outer':[0,1,2,14,15], 'split3':[0,1,2,8,9],
 'split2':[0,1,8,9,10], 'spaced':[0,3,6,9,12],
 'spaced_end':[3,6,9,12,15], 'even':[0,2,4,8,12],
 'odd':[1,3,7,11,15], 'ends':[0,7,8,14,15],
 'middle':[5,6,7,8,9], 'high_edges':[0,8,9,14,15],
}
variants={}
for name,pos in sets.items():
 assert len(pos)==len(set(pos))==5 and all(0<=i<16 for i in pos),(name,pos)
 rest=[i for i in range(16) if i not in pos]
 s=src.replace('const toAes = field.toAes;', 'const toAes = field.toAes;\nconst selected = [_]usize{ '+', '.join(map(str,pos))+' };\nconst remainder = [_]usize{ '+', '.join(map(str,rest))+' };')
 s=s.replace('for (0..5) |i| {','for (selected, 0..) |position, i| {',1).replace('unit[i] = 1;', 'unit[position] = 1;',1)
 s=s.replace('inline for (0..5) |i| {','inline for (selected, 0..) |position, i| {',1).replace('words[i / 8] >> @as(u6, @intCast(i % 8 * 8))','words[position / 8] >> @as(u6, @intCast(position % 8 * 8))',1)
 s=s.replace('inline for (5..16) |i| {\n            if ((i - 5) % 3 == group)', 'inline for (remainder, 0..) |i, ordinal| {\n            if (ordinal % 3 == group)')
 s=s.replace('inline for (0..5) |position| {','inline for (selected, 0..) |position, column| {').replace('forward_columns[position]', 'forward_columns[column]').replace('inverse_columns[position]', 'inverse_columns[column]')
 p=stage/name;shutil.copytree(stage/'baseline',p,dirs_exist_ok=True);(p/'hybrid.zig').write_text(s)
 variants[name]={'selected':pos,'remainder':rest,'groups':[rest[g::3] for g in range(3)]}
# Exact byte-for-byte duplicate baseline control, not the regenerated prefix.
shutil.copytree(stage/'baseline',stage/'control',dirs_exist_ok=True)
for p in [stage/'baseline',stage/'control']+[stage/n for n in sets]:
 for f in ['codegen.zig','correctness.zig']:shutil.copyfile(receipt/f,p/f)
shutil.copyfile(receipt/'pairs.zig',stage/'pairs.zig')
(stage/'variants.json').write_text(json.dumps(variants,indent=2)+'\n')
hashes={str(p.relative_to(stage)):hashlib.sha256(p.read_bytes()).hexdigest() for p in stage.rglob('*.zig')}
(stage/'source-hashes.json').write_text(json.dumps({'baseline':BASE,'files':hashes},indent=2)+'\n')
