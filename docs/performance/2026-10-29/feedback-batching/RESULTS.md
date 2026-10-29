# CBC/CFB feedback batching against released v0.9.0

Retained: CBC independent-feedback batching for IV registers >=64 blocks;
CFB batching for power-of-two IV registers >=64 blocks (measured IV64/128).
CFB IV65 keeps the original scalar encryption algorithm after its broader
candidate failed a portable short-call control. Updates shorter than 64 bytes
use the original scalar algorithms. No data-layout or public API change.

## Whole 16 KiB encryption

Elapsed candidate / baseline ratios, lower is better. Baseline is unchanged
v0.9.0 `d42d82cd4ece09b6281aac58cdcbe6edef5d43b7`, including its released
cipher kernel. Reductions include context initialization, IV copying, plaintext
copying, and public mode encryption; key expansion and allocation are excluded.
These gains are measured directly and are not sums of earlier isolated results.

| Operation | Native ratio | Less time | Portable ratio | Less time |
| --- | ---: | ---: | ---: | ---: |
| CBC-encrypt, IV64 | 0.078017 | 92.2% | 0.426596 | 57.3% |
| CBC-encrypt, IV65 | 0.084149 | 91.6% | 0.427960 | 57.2% |
| CBC-encrypt, IV128 | 0.077780 | 92.2% | 0.423531 | 57.6% |
| CFB-encrypt, IV64 | 0.065762 | 93.4% | 0.389220 | 61.1% |
| CFB-encrypt, IV128 | 0.066192 | 93.4% | 0.390011 | 61.0% |
| CFB-encrypt, IV65 | 0.998978 | 0.1% | 1.000602 | -0.1% |

The IV65 CFB row is an unchanged-algorithm control, not a speed claim.
`summary.json` and `summary.txt` include every tiny/threshold/large/split cell
and every run median; the JSONL files preserve all samples and full-output
checksums. Split calls occur after byte 1 for CFB or block 1 for CBC.

- native: worst aggregate control ratio 1.018224; worst potentially batched cell 1.009911.
- baseline: worst aggregate control ratio 1.029977; worst potentially batched cell 1.009924.

Split 16 KiB operations (same elapsed-time ratio):

| Operation | Native | Portable |
| --- | ---: | ---: |
| CBC-encrypt, IV64 | 0.080021 | 0.429364 |
| CBC-encrypt, IV65 | 0.086098 | 0.428953 |
| CBC-encrypt, IV128 | 0.080257 | 0.448890 |
| CFB-encrypt, IV64 | 0.068010 | 0.395349 |
| CFB-encrypt, IV128 | 0.068241 | 0.389618 |

None of the 672 aggregate cells exceeds 1.05. This is an aggregate regression
screen, not a claim that every individual noisy sample improved. See the
full run distributions in `summary.json`. Small differences within timing
noise are not speedups. In the retained configuration, the worst aggregate
ratio over all cells is below 1.03.

## Semantics and verification

Both loops encrypt at most `min(64, iv_blocks, remaining_full_blocks)` distinct
existing register entries before replacing them, including circular crossings.
CBC validates length before any write. CFB finishes pending feedback first,
then complete groups, then the original scalar tail. It updates the last
`stream` and `feedback` values exactly, even when `used == 16`. The private batch helper uses a bounded 64-block (1 KiB) stack buffer. No heap allocation,
field change, Cipher change, or decryption algorithm change is introduced.

The two new production tests use an independent byte shift-register reference
with single-block encryption for AES and Kuznechik. They cover IV1/2/3/63/64/65/128,
all 16 buffer alignments with guards, batch/IV wrap boundaries, all pending CFB
byte counts, CBC block splits, empty updates, continuation after partial tails,
full observable register/stream/feedback state, inverse output, and atomic CBC
length rejection. Existing RFC and authenticated-mode suites remain enabled.
`contracts.zig` compares every CBC/CFB field type/offset, size and alignment
against v0.9.0, and checks Cipher=352 bytes. `continuation.zig` independently
compares every context field and full output while changing direction on a
continuing context, including inverse paths that leave stale stream/feedback.

Final validation receipts:

| Target/backend | Baseline | Candidate |
| --- | --- | --- |
| Native LLVM Debug | 99 passed | 101 passed |
| Native ReleaseSafe | 99 passed | 101 passed |
| Native ReleaseFast | 99 passed | 101 passed |
| Native default Debug backend | 91 passed, 3 skips | 93 passed, 3 skips |
| Portable Debug/ReleaseSafe/ReleaseFast | 91 passed, 2 skips each | 93 passed, 2 skips each |
| AArch64 Linux ReleaseSafe | Test executable compiled | Test executable compiled |
| Context layout / direction continuation | — | 6/6 each (1 focused + 5 import-discovery tests) |
| Local zig build test ReleaseSafe | — | 93 passed, 2 skips |

Default native Debug uses Zig's self-hosted backend, which disables accelerated
paths and has an additional expected skip; the explicit LLVM Debug run covers
the full native suite. All cross-builds compile actual AArch64 ELF test
executables without attempting to execute them. Fresh disk-backed caches and
expected names/counts guard against stale test binaries.

## Reproduce and scope

Boat `bx_758ez2tt` (`kuz-ofb-r`), AMD Ryzen 9 9950X guest, Zig 0.15.1,
ReleaseFast, core 0. Native enables the guest's GFNI/AVX-512 block kernels;
`-mcpu=baseline` tests the portable backend on that same Zen 5 CPU, not a
separate older machine. Machine/compiler identity is in `lscpu.json`,
`uname.txt`, `zig-version.txt`, `compiler.sha256`, and `boat-owned.json`.

There are three runs per target, 336 cells per run, two warmup pairs plus nine
alternating measured pairs per cell: **18,144 measured pairs** in the final
six runs. Runtime keys, IVs and plaintexts vary with three seeds. Aligned,
unaligned and swapped buffers and reversed module placement control several
layout effects. Full outputs are compared and hashed after every pair.

Use `candidate-source.tar.gz` for a standalone source-only reproduction folder
at `/home/user/kuz-feedback-next`, then `bash run.sh` and `bash run-tests.sh`.
The bundle includes the exact baseline archive expected by the validation
runner. Or run `prepare.py` from this Git repository to create a fresh local
source-only folder. See `COMMANDS.md` for commands and timing boundaries,
`EXPERIMENTS.md` for rejected candidates, `source-sha256.txt` for every bundled
source/input hash and `SHA256SUMS` for the complete evidence inventory.
`analyze.py`, `report.py`, `archive.py` and `verify.py` regenerate the summaries,
report/chart, reproduction bundle, and validation of the receipts.

Limits: one virtualized CPU family, one compiler version, finite keys/lengths,
warm repeated operations, no universal speed or physical-optimality claim.
AES is a correctness adapter here, not a measured performance target. No
claim covers unmeasured IV widths, CPUs or compilers. Non-power-of-two CFB
batching remains a rejected hypothesis despite its large-message gains;
its tiny portable IV65 regression is preserved without omission.

All required source, raw measurements, identity, commands and exact test logs
were archived locally before the assigned VM was deleted. The deletion
request receipt is `boat-deleted.json` and completion is recorded in
`boat-deletion-status.json`; no other VM was touched. No push, PR, tag or
release was performed.
