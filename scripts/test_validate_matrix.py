"""Verify inventories reject silent coverage loss and accept recorded Zig logs."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('matrix', ROOT / 'scripts/validate-matrix.py')
matrix = importlib.util.module_from_spec(spec)
spec.loader.exec_module(matrix)


class InventoryTest(unittest.TestCase):
    def test_archived_full_suites(self):
        logs = list((ROOT / 'docs/validation/boat-x86-2026-10-30').glob('*.log'))
        self.assertEqual(len(logs), 11)
        for log in logs:
            with self.subTest(profile=log.stem):
                inventory = matrix.read_inventory(log.read_text())
                self.assertGreaterEqual(inventory['passed'], 97)

    def test_initial_arm_logs_keep_real_failure_visible(self):
        directory = ROOT / 'docs/validation/aarch64-2026-10-31/initial-baseline'
        for profile in ('baseline-debug', 'baseline-releasefast'):
            self.assertEqual(matrix.read_inventory((directory / (profile + '.log')).read_text())['passed'], 97)
        with self.assertRaises(ValueError):
            matrix.read_inventory((directory / 'baseline-releasesafe.log').read_text())

    def test_reject_missing_test_even_with_success_summary(self):
        with self.assertRaises(ValueError):
            matrix.read_inventory('1/2 first...OK\nAll 2 tests passed.\n')

    def test_reject_wrong_numbering_and_summary(self):
        for log in ('2/1 first...OK\nAll 1 tests passed.\n',
                    '1/1 first...SKIP\nAll 1 tests passed.\n', ''):
            with self.subTest(log=log), self.assertRaises(ValueError):
                matrix.read_inventory(log)


class BackendSupportTest(unittest.TestCase):
    diagnostic = ('error: CallAbiIterator.param(@Vector(16, u8))\n'
                  'error: CallAbiIterator.param(@Vector(32, u8))\n')

    def test_known_limit_is_narrow_and_rejects_crashes(self):
        self.assertTrue(matrix.known_unsupported('aarch64', '0.15.2', 1, self.diagnostic))
        for machine, version, code, diagnostic in (
                ('x86_64', '0.15.2', 1, self.diagnostic),
                ('aarch64', '0.16.0', 1, self.diagnostic),
                ('aarch64', '0.15.2', -11, self.diagnostic),
                ('aarch64', '0.15.2', 124, self.diagnostic),
                ('aarch64', '0.15.2', 1, 'unrelated compiler error')):
            self.assertFalse(matrix.known_unsupported(machine, version, code, diagnostic))

    def test_unsupported_requires_explicit_opt_in_and_is_not_a_pass(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            zig = root / 'zig'
            zig.write_text('#!/usr/bin/env python3\nimport sys\n'
                           'if sys.argv[1] == "version": print("0.15.2"); sys.exit(0)\n'
                           'if sys.argv[1] == "build-obj":\n'
                           f'    print({self.diagnostic!r},file=sys.stderr); sys.exit(1)\n'
                           'sys.exit(99)\n')
            zig.chmod(0o755)
            for allowed in (False, True):
                output = root / str(allowed)
                args = ['matrix', '--zig', str(zig), '--output', str(output)]
                if allowed:
                    args.append('--allow-known-unsupported')
                args.append('baseline-selfhosted-debug')
                with mock.patch.object(sys, 'argv', args), mock.patch.object(matrix.platform, 'machine', return_value='aarch64'), contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(bool(matrix.main()), not allowed)
                summary = json.loads((output / 'summary.json').read_text())
                self.assertEqual(summary['passed_profiles'], [])
                self.assertEqual(summary['unsupported_profiles'], ['baseline-selfhosted-debug'])
                self.assertFalse((output / 'baseline-selfhosted-debug.inventory.json').exists())

    def test_build_timeout_is_a_failure_with_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            out = Path(directory)
            env = dict(os.environ, ZIG_LOCAL_CACHE_DIR=str(out / 'local'), ZIG_GLOBAL_CACHE_DIR=str(out / 'global'))
            receipt = matrix.run_measured([sys.executable, '-c', 'import time;time.sleep(10)'], out, 'timeout', env, 0.05)
            self.assertEqual(receipt['exit_code'], 124)
            self.assertTrue(receipt['timed_out'])


if __name__ == '__main__':
    unittest.main()
