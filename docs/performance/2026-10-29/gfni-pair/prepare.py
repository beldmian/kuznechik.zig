#!/usr/bin/env python3
"""Extract exact source-only experiment copies; never create a checkout."""
from pathlib import Path
import argparse,tarfile,shutil
p=Path(__file__).resolve().parent
args=argparse.ArgumentParser()
args.add_argument('--phase',choices=['candidate','initial'],default='candidate')
phase=args.parse_args().phase
out=Path('/home/t3/.cache/kuz-gfni-pair-reproduce')/phase
out.mkdir(parents=True,exist_ok=True)
variants=['baseline','candidate','narrow','control','initial-candidate','inside','switch','wide','wide-switch']
with tarfile.open(p/'evidence.tar.gz') as t:
 selected=[]
 for member in t:
  f=Path(member.name)
  assert not f.is_absolute() and '..' not in f.parts
  if f.parts[0] in variants or len(f.parts)==1 and f.suffix in ['.zig','.sh','.py']:
   selected.append(member)
 t.extractall(out,members=selected,filter='data')
if phase=='initial':
 for name in ['kuznechik.zig','gfni_pair.zig']:
  shutil.copyfile(out/'initial-candidate/src'/name,out/'candidate/src'/name)
with tarfile.open(out/'transfer.tar.gz','w:gz') as t:
 for f in out.iterdir():
  if f.name in variants or f.suffix in ['.zig','.sh','.py']:t.add(f,arcname=f.name)
print(out)
