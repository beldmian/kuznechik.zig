# Independent review artifacts

These are the saved review drivers, fresh fixtures/generators, manifests, and
logs supporting the two reports in `docs/reviews`. The reports preserve the
original source hashes, commands, source snapshot and temporary evidence paths.
The files here provide a durable subset of that evidence without compiler caches,
executables, redundant source archives or third-party implementation copies.

Run the MGM/ACPKM driver from the project root:

```sh
cp docs/reviews/evidence/mgm-acpkm/review-driver.zig src/.saved_review.zig
zig test src/.saved_review.zig -O ReleaseSafe -mcpu=native --test-filter review
rm src/.saved_review.zig
```

The OCB/composition driver retains its original hash and temporary fixture paths.
Repoint those paths in a temporary copy before running:

```sh
python3 - <<'PY'
from pathlib import Path
p = Path('docs/reviews/evidence/ocb-compositions')
s = (p / 'review-driver.zig').read_text()
s = s.replace('/tmp/kuz-review-sol-awD48G/', str(p.resolve()) + '/')
Path('src/.saved_review.zig').write_text(s)
PY
zig test src/.saved_review.zig -O ReleaseSafe -mcpu=native --test-filter review_sol
rm src/.saved_review.zig
```

Use fresh, disk-backed local/global caches for an independent rerun. Test counts
can include unnamed declaration anchors; the reports distinguish them from new
named checks. The generators require Node's OpenSSL OCB and, for composition
fixtures, gostcrypto 1.2.5 solely as a raw block oracle. Neither is a runtime
library dependency. Running a generator replaces only its neighboring JSON file.
