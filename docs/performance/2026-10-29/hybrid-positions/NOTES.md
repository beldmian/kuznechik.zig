# Hybrid position experiment notes

Pinned baseline: released v0.9.1, peeled tag and main
`a518ff4aed72f1d9cfe8b923944ca68ec39b2d0f`.

Read before experimentation: root AGENTS.md, openspec/AGENTS.md,
optimize-block-cipher proposal/design/tasks and performance delta spec;
original hybrid source/history and hypotheses-hybrid-{encrypt,decrypt}.json;
operand-scheduling, bitwise-normalization and classic-feedback reports.
Their historical gains are not combined with this experiment's baseline.
The old width/group-count, whole-state encoding, per-round VBMI S-box,
forced-register coefficients and inverse endpoint constructor experiments
are not repeated. Scope is task 4.3, not a new dispatch or public interface.

The new owned VM is `bx_r9rh9mfv`, created by this worker using exactly
`boat new --no-env --no-snapshots --ttl 10800 --name kuz-hybrid-positions --json`.
JSONL is parsed per line in ownership.json. No other VM is accessed.
Compiler archive was transferred with Boat scp, extracted to disk, and both
hashes checked. Source trees are source-only snapshots extracted from Git
objects locally and transferred as a tar file; no Git checkout is created on
Boat. Build/test caches use unique directories under /home/user/.cache or
/home/t3/.cache, and never /tmp.

Initial build script mistakenly attempted a baseline-versus-itself module
import using the identical source path. Zig rejected this before any timed
run (`file exists in modules 'baseline' and 'candidate'`). The corrected script
uses a separate source-only `control` copy for the exact baseline comparison.
No failed-build results enter performance analysis.

All subsets retain five compressed positions, eleven 4KiB active lookup rows
per direction, and three dense ordinal-modulo-three integer groups. Lookup
row identities retain original byte positions. The generator changes only
column selection, GFNI extraction positions and the matching complement of
lookup rows/groups. It preserves every assembly constraint and all endpoint
lanes. Columns are derived at compile time using the baseline transform and
are separately derived/checked in screen.py from the field recurrence.

The finite analytical screen describes all 4,368 subsets by extraction shapes,
and verifies field homomorphism and basis products. Shapes do not predict
compiler scheduling; 16 structured families are compiled, including prefix
as a regeneration control. This is not an exhaustive subset search.

The harness uses actual Cipher.encrypt/decrypt for api=block, and actual
Cipher.encryptBlocks/decryptBlocks for api=blocks. Width zero in CLI selection
means the direct block API and is printed as length=1/api=block. Width one
means the singleton block-slice API. Repeated outputs feed subsequent calls;
wider slices consist of independent blocks. Both directions use unrelated
runtime bytes. Key expansion, allocations (there are none), resets, comparison,
hashing and printing are outside timing. Dispatch, all per-call preparation,
endpoints, padding and copies are inside. No external prepared key cache exists.

Each case uses three warmup pairs, then alternating before/after order with
shuffled case order, full-buffer equality after every pair, guard checks and
observable whole-buffer hashes. Buffers alternate roles and cycle four legal
16-byte block offsets modulo 64. Keys and inputs vary by runtime seed. Public
prevalidation uses zero, FF and fresh keys, lengths 0..127, four offsets and
independent ciphertext decryption. Independent basic-transform correctness,
basis tests and full named-entry test suites provide additional checks.

The initial harness also erroneously asserted nonempty input in its shared
wrapper, conflicting with the empty-slice prevalidation. The exact baseline
control rejected it before timing with OutputOrGuardMismatch. The assertion
was removed; empty batches reach the real public API. The rejected run is
preserved as invalid-empty-input-harness.jsonl and is excluded from analysis.
All timed binaries were rebuilt from the corrected harness.

The proof was subsequently extended (without modifying timed sources) to
6,144 independently computed dense seeded mixed-column rounds, including the
first-inverse substitution cancellation. All passed. The constants and complete
proof outputs are in screen.json.

The final confirmation candidates were chosen on different evidence:
boundary=[0,6,7,8,9] had the best non-control direct-encrypt exploration;
spaced=[0,3,6,9,12] had the best direct-decrypt exploration; and
split2=[0,1,8,9,10] had the lowest full wrapper instruction counts and gains
in both singleton slice calls. Their initial results were mixed, not wins.
No new count/group-count variants were warranted by those observations.

initial-source-hashes.json describes the first upload, including the erroneous
empty-input assertion. measured-source-hashes.json is authoritative for the
corrected timed sources. The complete corrected source archive is retained.

The complete required baseline native LLVM/Self-hosted/znver4/GFNI-off/VBMI-off
matrix passed, as did the additional AVX512VL-off check (100 pass, one skip).
An additional synthetic AVX2-off diagnostic on the exact unchanged baseline
failed compilation: `error: couldn't allocate output register for constraint 'v'`.
The initial validation loop stopped there before testing finalists. The failed
baseline log is retained and is not counted as a pass. This falls outside the
owned hybrid-only production scope; no unrelated kernel or feature gate is
changed. The final script excludes this extra diagnostic and resumes finalists
without rerunning already passed baseline tests. Baseline caches and the initial
validation script are separately preserved. This limitation is reported to root.
