"""Verify inventories reject silent coverage loss and accept recorded Zig logs."""
import importlib.util
from pathlib import Path
import unittest

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

    def test_reject_missing_test_even_with_success_summary(self):
        with self.assertRaises(ValueError):
            matrix.read_inventory('1/2 first...OK\nAll 2 tests passed.\n')

    def test_reject_wrong_numbering_and_summary(self):
        for log in ('2/1 first...OK\nAll 1 tests passed.\n',
                    '1/1 first...SKIP\nAll 1 tests passed.\n', ''):
            with self.subTest(log=log), self.assertRaises(ValueError):
                matrix.read_inventory(log)


if __name__ == '__main__':
    unittest.main()
