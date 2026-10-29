# Exact reproduction

Baseline: released v0.9.3, `567ab5e19531c2d746f6bfee489f58177933ea61`.
These scripts create source-only directories, never Git checkouts. No library
source in the working tree is changed by the experiment.

From the repository root, choose a fresh disk-backed stage:

```sh
D=docs/performance/2026-10-29/gfni-pressure-scheduling
S=/home/t3/.cache/kuz-gfni-pressure-reproduce
python3 "$D/prepare.py" . "$S"
python3 "$D/search.py" "$S"
python3 "$D/audit-sources.py" . "$S"
python3 "$D/audit-novelty.py" "$S"
python3 "$D/audit-pressure.py" "$S"
python3 "$D/audit-algebra.py" "$S"
cp "$D/"*.zig "$D/"*.sh "$D/codegen.py" "$S/"
```

`search.py` runs 24 bounded ready-list policies, deduplicating identical source
schedules. It writes 23 distinct schedules. For each it checks every byte basis
(therefore every binary basis) and 1,024 seeded dense cases. `prepare.py` derives
L independently from the recurrence and checks both directed scaled identities.
The released header, helper functions and endpoints are reproduced exactly.

For a new Boat reproduction, create your own VM, and parse each JSONL event
separately. Record the `created` event's id and require that subsequent events
refer to that id. Never reuse this experiment's deleted VM or any other VM.

```sh
boat new --no-env --no-snapshots --ttl 10800 --name kuz-pressure-reproduction --json
```

Transfer only source directories and harness/scripts to
`/home/user/kuz-gfni-pressure`, plus the Zig 0.15.1 archive. Extract the archive
under `/home/user`. Check archive SHA-256
`c61c5da6edeea14ca51ecd5e4520c6f4189ef5250383db33d01848293bfafe05`
and executable SHA-256
`0ee27482eb2e7b19fad58579c107364aa93fbfb54be2d2b9c52cef5f955d6225`.
The supplied VM scripts pin compiler/test jobs to CPU 2 and timings to CPU 0.
All compiler caches use unique directories under `/home/user/.cache`.

Run these **sequentially**, with no other timed or compiler/test jobs on that VM:

```sh
sh screen.sh
python3 codegen.py .
sh build-pairs.sh candidate ready00 ready12 ready18 ready19
sh explore.sh
sh confirm.sh
sh validate.sh
```

`candidate` is an unchanged second source copy of the baseline for the native
and portable baseline-v-baseline controls. `confirm.sh` compiles all additional
binaries before starting any timings. It reuses the exact forward binaries from
`build-pairs.sh`. Reversed runs swap modules and must have their raw paired ratios
inverted; `summarize.py` handles this.

For local portable and linked AArch64 checks:

```sh
sh "$D/local-validate.sh" "$S"
# Repeat with the ready00 source directory (see local-candidate-validate.sh).
sh "$D/local-candidate-validate.sh" "$S"
```

After copying all logs, assembly, source copies and raw JSONL files back to your
local stage, regenerate the audits and summaries:

```sh
python3 "$D/codegen.py" "$S"
python3 "$D/summarize.py" "$S"
python3 "$D/audit-tests.py" "$S"
python3 "$D/audit-binaries.py" "$S"
python3 "$D/audit-sources.py" . "$S"
python3 "$D/audit-novelty.py" "$S"
python3 "$D/audit-pressure.py" "$S"
python3 "$D/audit-algebra.py" "$S"
```

The exact original generated sources and assemblies are stored in compressed
archives. `SHA256SUMS` covers delivered evidence; source, assembly and binary
receipts identify the measured objects. No runtime binary cache is needed to
reproduce the public API measurements. Confirm complete local evidence before
permanently deleting the VM; inspect the asynchronous deletion operation until
its completed state is returned.
