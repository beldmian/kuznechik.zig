#!/usr/bin/env python3
"""Extract fixed v0.9.3 source-only copies; reproduce exact existing 70-map graph.
The historical derivation is pinned from v0.9.3, with only its baseline commit
parameter replaced. Nothing in production or another evidence directory is edited.
"""
import hashlib,json,pathlib,subprocess,sys
BASE='567ab5e19531c2d746f6bfee489f58177933ea61'
repo=pathlib.Path(sys.argv[1]).resolve();stage=pathlib.Path(sys.argv[2]).resolve()
derivation=subprocess.check_output(['git','-C',str(repo),'show',BASE+':docs/performance/2026-10-29/operand-scheduling/prepare.py']).decode()
derivation=derivation.replace("base = '40f77f43fd964a8ac528bf686ce7c1cda859424d'",'base = '+repr(BASE))
sys.argv=[__file__,str(repo),str(stage)]
exec(compile(derivation,'v0.9.3-derivation','exec'))
assert base==BASE
assert (stage/'candidate/toeplitz_core.zig').read_bytes()==(stage/'baseline/toeplitz_core.zig').read_bytes()
assert all(p.read_bytes()==(stage/'candidate'/p.relative_to(stage/'baseline')).read_bytes() for p in (stage/'baseline').rglob('*') if p.is_file())
(stage/'reproduction.json').write_text(json.dumps(dict(base=BASE,exact_all_source_reproduction=True,core_sha256=hashlib.sha256((stage/'baseline/toeplitz_core.zig').read_bytes()).hexdigest(),historical_derivation_sha256=hashlib.sha256(derivation.encode()).hexdigest()),indent=2)+'\n')
