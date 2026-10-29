#!/usr/bin/env python3
"""Source-only v0.9.4 fixtures. No working library files are modified."""
import hashlib,json,pathlib,subprocess,sys,shutil
repo=pathlib.Path(sys.argv[1]).resolve(); stage=pathlib.Path(sys.argv[2]).resolve()
BASE=subprocess.check_output(['git','-C',str(repo),'rev-parse','cd9c731']).decode().strip()
# Reuse the independently checked existing graph derivation; pin its extraction.
d= (repo/'docs/performance/2026-10-29/operand-scheduling/prepare.py').read_text()
d=d.replace("base = '40f77f43fd964a8ac528bf686ce7c1cda859424d'",'base = '+repr(BASE))
sys.argv=[__file__,str(repo),str(stage)]
exec(compile(d,'pinned-existing-derivation','exec'))
assert (stage/'baseline/toeplitz_core.zig').read_bytes()==(stage/'candidate/toeplitz_core.zig').read_bytes()
old=(stage/'baseline/toeplitz_core.zig').read_text()
start=old.index('    const code = comptime std.fmt.comptimePrint('); end=old.index('\n}',start)
body='''    // An eight-byte by-reference aggregate avoids Zig 0.15.1 scalar m lowering.
    // LLVM receives *m with elementtype([1 x i64]), the actual immutable matrix.
    return asm ("vgf2p8affineqb $0, %[m]{1to8}, %[a], %[out]"
        : [out] "=v" (-> T),
        : [a] "v" (a),
          [m] "*m" ([1]u64{matrix_pool[coefficient]}),
        : .{ .memory = true });'''
for name,helper in [('explicit-clobber',body),('explicit-read',body.replace('\n        : .{ .memory = true });','\n    );'))]:
 shutil.copytree(stage/'baseline',stage/name,dirs_exist_ok=True)
 (stage/name/'toeplitz_core.zig').write_text(old[:start]+helper+old[end:])
for name in ['baseline','candidate','explicit-clobber','explicit-read']:
 for file in ['algebra.zig','products.zig','codegen.zig']:
  shutil.copyfile(repo/'docs/performance/2026-10-29/gfni-memory-operands'/file,stage/name/file)
for p in (repo/'docs/performance/2026-10-29/gfni-memory-operands').iterdir():
 if p.suffix in ['.py','.sh','.zig']:shutil.copyfile(p,stage/p.name)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest={name:{str(p.relative_to(stage/name)):sha(p) for p in (stage/name).rglob('*') if p.is_file()} for name in ['baseline','candidate','explicit-clobber','explicit-read']}
for name,files in manifest.items():
 for f,h in files.items():
  if f!='toeplitz_core.zig':assert h==manifest['baseline'][f]
(stage/'source-audit.json').write_text(json.dumps(dict(base=BASE,only_helper_changed=True,sources=manifest),indent=2)+'\n')
