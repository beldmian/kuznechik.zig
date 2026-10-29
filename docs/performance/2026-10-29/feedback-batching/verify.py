#!/usr/bin/env python3
"""Validate cell counts, baseline identity, source archives and test receipts."""
import hashlib,json,pathlib,tarfile,subprocess
root=pathlib.Path(__file__).resolve().parent
with tarfile.open(root/'candidate-source.tar.gz') as tf:
    def read(n):return tf.extractfile(n).read()
    actual=read('src/modes/classic_before_090.zig')
    expected=subprocess.check_output(['git','show','d42d82cd4ece09b6281aac58cdcbe6edef5d43b7:src/modes/classic.zig'])
    assert actual==expected
    assert read('src/modes/classic.zig')==pathlib.Path('src/modes/classic.zig').read_bytes()
bundled=dict(line.split('  ',1)[::-1] for line in (root/'source-sha256.txt').read_text().splitlines())
for line in (root/'vm-source-sha256.txt').read_text().splitlines():
    digest,name=line.split('  ',1)
    assert bundled[name]==digest, ('VM source differs from archive',name)
for target in ['native','baseline']:
    for placement in ['forward1','forward2','reverse']:
        rows=[json.loads(s) for s in (root/f'{target}-{placement}.jsonl').read_text().splitlines()]
        assert len(rows)==336
        assert len({(r['mode'],r['m'],r['bytes'],r['split1']) for r in rows})==336
        for r in rows:
            assert len(r['before'])==len(r['after'])==9
            assert min(r['before']+r['after'])>0
assert (root/'validation-complete.txt').read_text().strip()=='ALL VALIDATION COMMANDS PASSED'
for variant,passed in [('baseline',99),('candidate',101)]:
    for mode in ['ReleaseSafe','ReleaseFast','Debug-llvm']:
        s=(root/f'{variant}-native-{mode}.log').read_text()
        assert f'All {passed} tests passed.' in s
        if variant=='candidate':
            assert 'CBC CFB AES independent encryption registers' in s
            assert 'CBC CFB Kuznechik independent encryption registers' in s
    for mode in ['Debug','ReleaseSafe','ReleaseFast']:
        s=(root/f'{variant}-baseline-{mode}.log').read_text()
        assert f'{passed-8} passed; 2 skipped; 0 failed.' in s
    s=(root/f'{variant}-native-Debug.log').read_text()
    assert f'{passed-8} passed; 3 skipped; 0 failed.' in s
    s=(root/f'{variant}-aarch64.log').read_text()
    assert 'ARM aarch64' in s
for name in ['contracts','continuation']:
    log=(root/f'{name}.log').read_text()
    assert 'All 6 tests passed.' in log
    assert ('v0.9.0 feedback contexts' if name=='contracts' else 'feedback state continuation') in log
cleanup=json.loads((root/'boat-deletion-status.json').read_text())['operation']
assert cleanup['targetId']=='bx_758ez2tt' and cleanup['status']=='completed' and cleanup['completedAt']
for line in (root/'SHA256SUMS').read_text().splitlines():
    checksum,name=line.split('  ',1)
    assert hashlib.sha256((root/name).read_bytes()).hexdigest()==checksum,name
print('PASS: 2016 final cells, 18144 measured pairs, exact v0.9.0 baseline, source archive, test receipts and evidence hashes')
