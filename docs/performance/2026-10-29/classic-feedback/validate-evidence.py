#!/usr/bin/env python3
"""Run from the repo root; reject stale/partial evidence or mismatched source."""
from pathlib import Path
import hashlib
import json
import re

p = Path(__file__).resolve().parent

def names(path):
    return set(re.findall(r'^\d+/\d+ (.*?)\.\.\.', path.read_text(), re.M))

baseline_names = names(p / 'baseline-native-safe.log')
for name, count, trailer in [
    ('retained-tests-native.log', 76, 'All 76 tests passed.'),
    ('retained-tests-native-fast.log', 76, 'All 76 tests passed.'),
    ('retained-tests-portable.log', 70, '68 passed; 2 skipped; 0 failed.'),
]:
    path = p / name
    found = names(path)
    assert len(found) == count, (name, len(found))
    assert baseline_names <= found, (name, baseline_names - found)
    assert trailer in path.read_text(), name
    print(name, 'verified distinct names:', count, '; baseline names preserved')
for line in (p / 'retained-source-sha256.txt').read_text().splitlines():
    digest, path = line.split(maxsplit=1)
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == digest, path
baseline = (p / 'baseline-classic.zig.txt').read_text()
source = Path('src/modes/classic.zig').read_text()
assert (p / 'classic-before.zig').read_text() == baseline.split('\ntest "', 1)[0] + '\n'
assert (p / 'retained-classic.zig.txt').read_text() == source
for start, end in [
    ('        pub fn Cfb(', '        pub fn Ofb('),
    ('        pub const Cmac = struct {', '\ntest "'),
]:
    assert source.split(start, 1)[1].split(end, 1)[0] == baseline.split(start, 1)[1].split(end, 1)[0]
print('Measured source/harness hashes and snapshots match; CFB and CMAC unchanged.')
rows = json.loads((p / 'summary.json').read_text())
assert len(rows) == 272
for r in rows:
    assert len(r['runs']) == 3
    if r['mode'] == 'OFB-xor' and r['m'] >= 64:
        assert r['median_ratio'] <= 1.05, r
print('272 target/configuration summaries, three controls each; no changed OFB median regression >5%.')
cleanup = json.loads((p / 'boat-cleanup-status.json').read_text())['operation']
assert cleanup['targetId'] == 'bx_vvgmu7aw' and cleanup['status'] == 'completed'
print('Owned VM deletion completed:', cleanup['completedAt'])
