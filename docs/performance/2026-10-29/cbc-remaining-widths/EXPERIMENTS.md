# CBC coverage experiment

The sole production candidate replaces v0.9.3's measured-width switch with
`iv_blocks >= 2`. No batching algorithm, scalar body, threshold or cipher kernel
is changed. Earlier medium-feedback and feedback-batching evidence informed
this hypothesis, but every ratio here uses exact v0.9.3 on both sides. Historical
v0.9.0/v0.9.2 gains are not combined with these results.

The newly eligible widths are IV5/6/7/9/10/11/12/13/14/15/17/18/19/20/21/22/23/
25/26/27/28/29/30/33/34/35/36/37/38/39/40/41/42/43/44/45/46/47/48/49/50/51/
52/53/54/55/56/57/58/59/60/61/62. The other 13 widths in the timing grid are
unchanged controls, including default IV1, IV2/3 and IV64/65/128.

1. Run the complete short/threshold/ring/whole/split matrix with three seeds,
   both targets, reversed module placement, aligned/unaligned/swapped buffers,
   and a separate unchanged baseline-versus-baseline grid. Every measured pair
   passes complete-output independent-reference and guard validation. Initial
   newly batched aggregate maxima are 0.737960 native and 0.757182 portable.
2. The native IV29 whole-16-byte scalar cell has an initial aggregate 1.032563
   (run medians 1.032563/1.015650/1.074125), while unchanged-baseline aggregate
   controls reach 1.047806 elsewhere. This does not establish that all tiny
   costs are noise: the corresponding unchanged IV29 cell is near unity.
   Preserve every sample and add two seeds over the *whole grid* in both
   compiler targets and the unchanged controls. Do not select only favorable
   widths, lengths, pairs or independent minima. `initial-analysis.txt` retains
   the initial three-seed decision record.
3. Run the expanded correctness inventories and exact-v0.9.3 contract/state
   drivers separately from timing. Two local full portable ReleaseSafe compile
   attempts receive SIGKILL/137 before any tests emit (default jobs, then -j1
   with fresh caches); neither is a pass. The local focused tests pass 7/7;
   all full VM receipts and the local failure note are retained separately.
4. The expanded layout driver initially exceeds Zig's default 1000 backwards
   branches at compile time. Preserve `attempts/contracts-branch-quota.log`,
   raise only the evidence drivers' compile-time quota to 100000, and run both
   drivers with fresh caches. The linked AArch64 ELF already succeeded; all
   completed main-source suites remain valid because their source is unchanged.
   `finish.sh` records the actual recovery/supplemental/archive command sequence;
   a clean reproduction runs run-tests.sh directly with the corrected drivers.
5. Capture exported CBC wrappers for all measured widths in native and portable
   assembly/object/nm artifacts. These are supporting code-generation evidence,
   never substituted for the public-API performance matrix.

The supplemental seed outcomes and final decision are in RESULTS.md and the
complete `final-summary.json.gz` / `control-summary.json.gz` distributions.
No rejected CFB experiment is repeated. IV2 threshold128, IV3 threshold48,
default IV1, existing >=64 paths, decryption, bounded scratch and all CFB
production lines remain unchanged.
