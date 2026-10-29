# Root integration and auditor correction

Root integrates author evidence commit
`b9a4dc2cda2db6c01ad394cf72647c91fee49eed`. Library source remains identical
to released v0.9.4. The experiment itself compares exact v0.9.3; its prototype
test counts are not presented as tests of the newer production tree.

Root found an indentation error in the original archive auditor's default
worktree-restoration branch: it compared only the last baseline source file.
The archived source hashes, exact Git baseline and experimental allowed-scope
checks were already complete. Root fixed the loop and added an exact source-file
set check. It also added `--skip-worktree` for explicitly auditing historical
archives from a newer source revision; that mode reports the skipped check and
still validates the archive, Git baseline and experimental source scope.

The corrected auditor passes against the author's restored v0.9.3 worktree.
As a negative check it rejects current v0.9.4 because `src/modes/classic.zig`
has changed since the experiment's baseline. Explicit archive-only mode passes
and does not claim to verify the current worktree. `root-recheck.json` records
these outcomes.

Root also rechecked all 358 archived source hashes, the archive SHA-256,
33,768 matched timing pairs, 13 complete named test inventories, and both paired
summary files regenerated from the raw measurements. Everything matches the
author records. The compressed evidence archive and original author reports
remain unchanged. `ROOT-SHA256SUMS` covers the corrected auditor and integration
records along with the delivered top-level evidence files.

Use the corrected auditor from a v0.9.3 source checkout for strict restoration
checking. From a newer revision, pass `--skip-worktree` when the purpose is to
check only the historical archive. Git must contain the pinned release object.
The original `verification.txt` records the author's historical invocation;
the corrected full-worktree verification is documented here separately.

No prototype enters production. The experiment's owned VM deletion was already
confirmed completed. This evidence-only integration allocates no VM and does
not bump the library version or claim physical optimality.
