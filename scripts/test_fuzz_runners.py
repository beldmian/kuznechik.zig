"""Exercise runner naming and worker arguments without requiring AFL/QEMU."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
NAMES = {'roundtrip': ('fuzz-round-trip', 'round_trip'),
         'key_schedule': ('fuzz-key-schedule', 'key_schedule'),
         'ls_roundtrip': ('fuzz-ls-roundtrip', 'ls_roundtrip')}


class RunnerTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.cwd = Path(self.tmp.name)
        (self.cwd / 'bin').mkdir()
        (self.cwd / 'calls').mkdir()
        for _, corpus in NAMES.values():
            (self.cwd / 'test/fuzz/corpus' / corpus).mkdir(parents=True)
        fake_afl = self.cwd / 'bin/afl-fuzz'
        fake_afl.write_text('''#!/usr/bin/env python3
import json,os,sys,tempfile
with tempfile.NamedTemporaryFile(mode='w',dir=os.environ['CALLS'],suffix='.json',delete=False) as f:
    json.dump(sys.argv[1:],f)
''')
        fake_zig = self.cwd / 'bin/zig'
        fake_zig.write_text('''#!/usr/bin/env python3
import os,sys
from pathlib import Path
Path(os.environ['BUILD_CALL']).write_text(' '.join(sys.argv[1:]))
''')
        fake_afl.chmod(0o755)
        fake_zig.chmod(0o755)
        self.env = dict(os.environ, PATH=str(self.cwd / 'bin') + os.pathsep + os.environ['PATH'],
                        CALLS=str(self.cwd / 'calls'), BUILD_CALL=str(self.cwd / 'build-call'))

    def run_script(self, script, *args):
        return subprocess.run(['bash', str(ROOT / 'scripts' / script), *args], cwd=self.cwd,
                              env=self.env, capture_output=True, text=True, timeout=10)

    def test_names_and_independent_dumb_workers(self):
        for name, (step, corpus) in NAMES.items():
            for script, extra in (('fuzz-dumb.sh', []), ('fuzz-qemu.sh', []),
                                  ('fuzz-parallel.sh', ['dumb', '2']),
                                  ('fuzz-parallel.sh', ['qemu', '2'])):
                with self.subTest(name=name, script=script, args=extra):
                    for file in (self.cwd / 'calls').iterdir():
                        file.unlink()
                    result = self.run_script(script, name, *extra)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual((self.cwd / 'build-call').read_text(), 'build ' + step)
                    calls = [json.loads(file.read_text()) for file in (self.cwd / 'calls').glob('*.json')]
                    self.assertEqual(len(calls), 2 if extra else 1)
                    outputs = set()
                    for call in calls:
                        self.assertEqual(call[call.index('-i') + 1], 'test/fuzz/corpus/' + corpus)
                        self.assertEqual(call[-2:], ['--', './zig-out/bin/' + name])
                        outputs.add(call[call.index('-o') + 1])
                        if '-n' in call:
                            self.assertNotIn('-M', call)
                            self.assertNotIn('-S', call)
                    if extra == ['dumb', '2']:
                        self.assertEqual(len(outputs), 2)
                    if extra == ['qemu', '2']:
                        self.assertEqual(sum('-M' in call for call in calls), 1)
                        self.assertEqual(sum('-S' in call for call in calls), 1)

    def test_replay_returns_target_exit_code(self):
        binary = self.cwd / 'zig-out/bin/key_schedule'
        binary.parent.mkdir(parents=True)
        binary.write_text('#!/bin/sh\nexit 42\n')
        binary.chmod(0o755)
        seed = self.cwd / 'seed'
        seed.write_bytes(bytes(32))
        result = self.run_script('fuzz-reproduce.sh', 'key_schedule', str(seed))
        self.assertEqual(result.returncode, 42)
        self.assertIn('Exit code: 42', result.stdout)


if __name__ == '__main__':
    unittest.main()
