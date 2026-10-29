# Reproduction

Run from the repository root. Scripts create only source copies, never checkouts.
The working library source is not modified. Zig compiler/system files are not edited.

```
D=docs/performance/2026-10-29/gfni-memory-operands
S=/home/t3/.cache/kuz-gfni-memory-stage
python3 "$D/prepare.py" . "$S"
tar -czf /home/t3/.cache/kuz-gfni-memory-input.tar.gz -C "$S" .
boat new --no-env --no-snapshots --type large --ttl 10800 --name kuz-gfni-memory --json
```

Parse JSONL one event at a time; record the `created` event id and require all
following events to refer to that id. Use only that exclusively owned VM.
Transfer the input archive and `/home/t3/.cache/kuz-other-toolchains/zig.tar.xz`
with `boat scp`; extract respectively under `/home/user/kuz-gfni-memory` and
`/home/user`. Verify hashes against `vm-compiler.sha256` before compiling.
Original VM: `bx_fkjyea7w`, created by this worker. Never reuse that id.

On the fresh owned VM, sequentially:

```
cd /home/user/kuz-gfni-memory
sh build.sh > build.log 2>&1
sh measure.sh > measure.log 2>&1
sh validate.sh > validate.log 2>&1
```

Compiler and test jobs use CPU 2, timings CPU 0. All caches are unique disk-backed
`/home/user/.cache/gfni-memory-*` directories. No other workload runs on this VM.
Native Debug explicitly uses `-fllvm`; self-hosted Debug is a separate fallback.
`validate.sh` also compiles and links AArch64 with `--test-no-exec`; this is not an
AArch64 runtime test. All baseline source comes from the exact cd9c731 Git object.
`candidate` is a byte-identical second baseline source copy for controls.
`explicit-clobber` and `explicit-read` change only the multiply helper body.
Their old generator-reference header is unchanged because neither is retained as
production source; `prepare.py` is the authoritative experimental generator.

The measured sources and frozen prelaunch scripts are preserved in
`measured-sources.tar.gz`, with their original hashes in `source-audit.json` and
`frozen-scripts.sha256`. `proof.json` comes from the pinned independent recurrence
and recursive graph derivation in operand-scheduling. The new `products.zig`
uses polynomial long division and a reconstructed affine matrix as independent
oracles, exercising actual GFNI products in all 64 lanes for every coefficient
and byte, plus repeated mixed optimized/inlined calls. `algebra.zig` exercises
byte basis and 1,024 lane-distinct dense states per direction with seeded keys.

After every VM phase completes, run `package-vm.py` there. Transfer its archive
and SHA receipt back. Verify every artifact against `vm-artifacts.sha256.json`.
Extract the archive into a local evidence stage, then:

```
python3 "$D/codegen.py" "$S"
python3 "$D/audit-codegen.py" "$S"
python3 "$D/summarize.py" "$S"
python3 "$D/audit-tests.py" "$S"
```

`summary.json` uses medians of paired candidate/baseline ratios, inverting each
ratio for reverse module placement. It preserves all per-case timings,
quantiles, per-offset medians, ns/block and checksums. It never compares minima.
The actual nine timed binaries have complete objdump logs and SHA receipts.
The three portable binaries must have no GFNI or ZMM instruction.

Preserve and verify evidence locally before `boat delete OWNED_ID --yes --json`.
Inspect its returned deletion operation with `boat deletion status OPERATION --json`
until completed, and retain the request and completion receipts.

The original complete VM evidence is `vm-evidence.tar.gz` (302 verified files).
It includes all raw JSONL, complete assembly/LLVM IR/object files, nine timed
binary disassemblies and readonly pools, named test logs, cache receipts,
source-only fixtures and original scripts. `vm-artifacts.sha256.json` hashes
each member. Actual executable identities are in `binaries.sha256`; the AArch64
ELFs and timed executables are omitted from the archive, with their hashes kept.

```
python3 "$D/verify-transfer.py" "$D/vm-evidence.tar.gz" "$S"
python3 "$D/audit-sources.py" . "$S"
python3 "$D/audit-novelty.py" . "$S"
```

`audit-codegen.py` uses pure Python to inspect ELF sections, checks each real
explicit RIP-relative broadcast against the actual executable readonly bytes,
and verifies pre/post-run binary hashes. `summarize.py` also checks all matching
runtime-seed/output checksums across executables; offset keys are byte offsets
modulo 64. `test-audit.json` inventories all 39 runtime logs and verifies the three linked
AArch64 compile receipts preserved in the VM archive. `regeneration.json` confirms fresh source
regeneration matches every fixture byte. `comparison.html` is the static chart.
The API outage and historical fallback receipt are diagnostic history only;
never reconnect to the deleted VM or reuse its former SSH port.

The delivered `summary.json.gz` and `test-audit.json.gz` compress the exact
locally audited JSON outputs. Decompress them for inspection; reproduction
auditors write ordinary `summary.json` and `test-audit.json` in the stage.
