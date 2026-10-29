#!/usr/bin/env python3
"""Create benchmark-only source copies; never changes the working source tree."""
import io, pathlib, shutil, subprocess, sys, tarfile
repo = pathlib.Path(sys.argv[1]).resolve()
out = pathlib.Path(sys.argv[2]).resolve()
base = subprocess.check_output(['git', '-C', str(repo), 'rev-parse', 'b2c467c^{commit}'], text=True).strip()
archive = subprocess.check_output(['git', '-C', str(repo), 'archive', base, 'src'])
dest = out / 'baseline'
if dest.exists(): shutil.rmtree(dest)
dest.mkdir(parents=True)
with tarfile.open(fileobj=io.BytesIO(archive)) as tf:
    for m in tf.getmembers():
        if not m.isfile(): continue
        path = pathlib.PurePosixPath(m.name).relative_to('src')
        target = dest / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(tf.extractfile(m).read())
dest = out / 'opposite'
if dest.exists(): shutil.rmtree(dest)
shutil.copytree(out / 'baseline', dest)
p = out / 'opposite/kuznechik.zig'
s = p.read_text()
s = s.replace('if (messages.len <= 24) return cryptGfniTail(inverse, cipher, messages);',
              'if (messages.len == 0 or messages.len == 1 or messages.len > 24) return cryptGfniTail(inverse, cipher, messages);')
s = s.replace('if (messages.len > 24) return cryptGfniPadded(inverse, 64, cipher, messages);',
              'if (messages.len <= 24) return cryptGfniPadded(inverse, 64, cipher, messages);')
s = s.replace('inline for (.{ 4, 8, 12, 16, 20, 24 }) |width|',
              'inline for (.{ 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60, 64 }) |width|')
p.write_text(s)
# Narrow production candidate: use fresh Toeplitz for standalone21..23 only;
# retain the matrix24 exact width and the prepared-tail policy.
dest = out / 'candidate'
if dest.exists(): shutil.rmtree(dest)
shutil.copytree(out / 'baseline', dest)
p = dest / 'kuznechik.zig'
s = p.read_text()
s = s.replace('cryptGfniTail(false, &self, remaining)', 'cryptGfniTail(false, true, &self, remaining)')
s = s.replace('cryptGfniTail(true, &self, remaining)', 'cryptGfniTail(true, true, &self, remaining)')
s = s.replace('cryptGfniTail(inverse, cipher, messages)', 'cryptGfniTail(inverse, false, cipher, messages)')
s = s.replace('fn cryptGfniTail(comptime inverse: bool, cipher:', 'fn cryptGfniTail(comptime inverse: bool, comptime standalone: bool, cipher:')
s = s.replace('    // Paired measurements of every tail 1..63 include all padding/copy costs.', '''    // Only standalone Zen 5 calls showed a repeatable benefit at 21..23.
    // The exact 24-block matrix and tails with reusable keys keep their policy.
    if (comptime use_scalar and standalone) {
        if (messages.len >= 21 and messages.len <= 23) return cryptGfniPadded(inverse, 64, cipher, messages);
    }
    // Paired measurements of every tail 1..63 include all padding/copy costs.''')
s = s.replace('    // smaller calls. Larger tails favor one padded 64-block recurrence kernel.',
              '    // smaller calls. Larger tails favor one padded 64-block kernel.')
p.write_text(s)
# Complete the width1 comparison: the regular sweep retains the released scalar
# lane as a control. These variants force matrix4 or Toeplitz64 for that lane.
for name, toeplitz_one in (('one-matrix', False), ('one-toeplitz', True)):
    dest = out / name
    if dest.exists(): shutil.rmtree(dest)
    shutil.copytree(out / 'baseline', dest)
    p = dest / 'kuznechik.zig'
    s = p.read_text().replace('if (messages.len <= 1) {', 'if (messages.len == 0) {')
    one = '''    if (messages.len == 1) {
        if (inverse) cipher.decrypt(&messages[0]) else cipher.encrypt(&messages[0]);
        return;
    }
'''
    assert one in s
    s = s.replace(one, '    if (messages.len == 1) return cryptGfniPadded(inverse, 64, cipher, messages);\n' if toeplitz_one else '')
    p.write_text(s)
# In the opposite sweep, the shared width64 helper still selects Toeplitz.
# Explicitly compare the remaining widths61..63 with true matrix64 kernels.
dest = out / 'matrix64'
if dest.exists(): shutil.rmtree(dest)
shutil.copytree(out / 'baseline', dest)
p = dest / 'kuznechik.zig'
s = p.read_text()
helper = '''fn cryptMatrix64(comptime inverse: bool, cipher: *const Cipher, messages: []align(16) block) void {
    var padded: [64]block align(16) = @splat(@as(block, @splat(0)));
    @memcpy(padded[0..messages.len], messages);
    if (inverse) gfni.decrypt(16, &cipher.ik, &padded) else gfni.encrypt(16, &cipher.ik, &padded);
    @memcpy(messages, padded[0..messages.len]);
}
'''
s = s.replace('fn cryptToeplitzTail(', helper + '\nfn cryptToeplitzTail(', 1)
s = s.replace('    if (messages.len <= 24) return cryptGfniTail(inverse, cipher, messages);',
              '    if (messages.len >= 61) return cryptMatrix64(inverse, cipher, messages);\n    if (messages.len <= 24) return cryptGfniTail(inverse, cipher, messages);')
s = s.replace('    if (messages.len > 24) return cryptGfniPadded(inverse, 64, cipher, messages);',
              '    if (messages.len >= 61) return cryptMatrix64(inverse, cipher, messages);\n    if (messages.len > 24) return cryptGfniPadded(inverse, 64, cipher, messages);')
p.write_text(s)
