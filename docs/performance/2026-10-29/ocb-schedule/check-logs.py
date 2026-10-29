#!/usr/bin/env python3
"""Verify unfiltered test logs contain the actual OCB tests, not stale binaries."""
from pathlib import Path
import re
P=Path(__file__).resolve().parent
names=['RFC7253 Appendix A all sixteen AES128 tuples and tag96 tuple','RFC7253 Appendix A all nine aggregate checksums','394 independent Node OpenSSL OCB fixtures','Kuznechik OCB all small tails 64-block boundaries every alignment guards and rejection','OCB fixed dimensions budget and alias failures preserve output','OCB key storage aliases and read-only sharing','OCB independent work batches stop at64 and open authenticates in a separate pass','generic RFC7253 empty nonce','OCB schedule length full-block powers including inclusive L48 endpoint','OCB bounded schedule independent AAD and payload powers full and partial']
lines=[]
logs=sorted((P/'logs').glob('test-*.log'))
assert len(logs)==8, len(logs)
for file in logs:
 text=file.read_text()
 expected=names[:8] if 'baseline-' in file.name else names
 for name in expected: assert name in text,(file,name)
 assert re.search(r'All \d+ tests passed\.|\d+ passed; \d+ skipped; 0 failed\.',text),file
 numbered=[l for l in text.splitlines() if re.match(r'\d+/\d+ ',l)]
 assert len(numbered)==int(numbered[-1].split('/')[1].split()[0]),file
 lines.append(f'{file.name}: {text.splitlines()[-1]} ({len(numbered)} test entries)')
 for line in numbered:
  if 'SKIP' in line: lines.append('  '+line)
lines.append('All eight logs contain all expected original OCB tests; all six candidate logs also contain both added schedule tests.')
(P/'test-results.txt').write_text('\n'.join(lines)+'\n')
print('\n'.join(lines))
