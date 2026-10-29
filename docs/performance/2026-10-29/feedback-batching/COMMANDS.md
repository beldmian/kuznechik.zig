# Commands and setup boundaries

Repository worktree began at released v0.9.0 commit
`d42d82cd4ece09b6281aac58cdcbe6edef5d43b7`. No checkout was created.
The assigned Boat VM was `bx_758ez2tt` (`kuz-ofb-r`), exclusively used for these
measurements. Sources lived in `/home/user/kuz-feedback-next`, a source-only
folder created for this experiment; `/home/user/kuz-090` was not modified.
Ownership/expiry observations are in `boat-owned.json`.

```sh
# Local preparation (from repository root):
python3 docs/performance/2026-10-29/feedback-batching/prepare.py
# prepare.py extracts the exact release commit, copies the candidate classic.zig,
# and creates the reversed driver. Copy its output contents into the VM folder.
boat ssh bx_758ez2tt 'mkdir -p /home/user/kuz-feedback-next'
# boat scp -r may add an extra basename directory; flatten that if necessary.
boat scp -r /home/t3/.cache/kuz-feedback-next/. bx_758ez2tt:/home/user/kuz-feedback-next/

# Measurement, from the VM source folder:
bash run.sh
# run.sh compiles ReleaseFast with -mcpu=native and -mcpu=baseline.
# Each target runs forward seeds 271828/layout0, 314159/layout3,
# then reversed placement seed 1618033/layout1, budget 262144 bytes.
# All timed work is pinned to CPU 0. No other benchmark or compiler ran
# concurrently with a complete measurement run.

# The exact v0.9.0 source archive is also supplied for baseline suite execution:
bash run-tests.sh
# Fresh per-invocation disk caches; native and portable Debug/Safe/Fast,
# native LLVM Debug, AArch64 compile, context layouts and continuation.
# Final refinement reused the identical baseline logs and ran:
bash run-tests.sh candidate
# An explicit baseline LLVM Debug check was added before final timing.

# Gather VM identity:
uname -a
lscpu -J
/tmp/zig-x86_64-linux-0.15.1/zig version
sha256sum /tmp/zig-x86_64-linux-0.15.1/zig
# Full archived-source hashes are in source-sha256.txt and SHA256SUMS.

# Local analysis after downloading raw JSONL:
python3 docs/performance/2026-10-29/feedback-batching/analyze.py
```

`refine.sh` records the transition from automatic helper inlining to noinline
helpers. `final-run.sh` records the transition from all large CFB widths to
power-of-two CFB widths. Those scripts assume the preceding experiment exists;
for clean final reproduction use `prepare.py`, `run.sh`, and `run-tests.sh`.

Each repetition times mode context initialization, plaintext copying, and a
complete public encryption operation. Allocations, random generation and key
expansion occur before timing. Whole operations use one call. Split operations
use two calls, after byte 1 for CFB or block 1 for CBC. Empty second calls are
included for the tiny cases. IV-register copying is inside timing. Every pair
compares the complete output and hashes all output bytes outside timing.
Memory barriers prevent elimination across repetitions.

Each cell has two discarded warmup pairs and nine alternating measured pairs.
There are 336 cells per run: two modes, IV1/2/3/63/64/65/128, whole/split,
CFB lengths 1/15/16/48/63/64/65/80/1008/1024/1040/2048/16384/65536,
CBC complete-block lengths from that list. Three run sets per target vary the
runtime key/IV/plaintext seed, output-buffer alignment and placement. Layout 0
is aligned; layouts 3 and 1 are offset by one byte; layout 3 swaps the two output
buffers. The third run reverses baseline/candidate module placement and labels;
analysis inverts its pair ratios. Medians are computed per pair, then per run,
then across the three run medians. Raw outliers are retained.

After all logs and source were downloaded, `archive.py` and `verify.py` passed
before cleanup. VM deletion was requested with:

```sh
boat delete bx_758ez2tt --yes --json
boat deletion status bdop_3a4f905b35b14ee5a7bb0e27d64b8fbc --json
```

The request and completed operation are saved separately as `boat-deleted.json`
and `boat-deletion-status.json`. No VM provisioning or lifetime extension was
needed.
