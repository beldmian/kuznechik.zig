# Medium-feedback experiment history

All cipher/mode dependencies start at exact released v0.9.2
`69d7ed3a2db775071fe331eb667b84283eaafb0d`. Older v0.9.0 and 75-map results
are background only. No isolated gains are added together.

1. **Broad 64-byte dispatcher.** `variants/broad64.zig` extends CBC to IV>=2,
   CFB to IV2..63 plus its existing large power-of-two registers, retaining a
   64-byte call/loop threshold. Buffers are min(64, iv_blocks) blocks. The
   pilot measures 13 widths with both targets, whole and split, eight lengths.
   Large calls improve, including padded native IV2/3 tails and portable
   interleaving. IV2 native gains near the threshold are too small to call a
   win. Raw 832 rows are in `variants/pilot/`; source and pilot driver are kept.
   This exploratory configuration is not retained.
2. **Conservative IV2 threshold, lower IV3 threshold, inline scalar path.**
   `variants/threshold-measured.zig` is the exact VM source used for the full
   six-run candidate. IV2 dispatch starts at 128 bytes; IV3 dispatch and the
   helper loop start at 48. Others start at 64. CBC controls remain stable.
   CFB IV8 whole-16-byte native medians are 1.0550/1.0418/1.0714 (aggregate
   1.0550); portable IV63 whole-16-byte medians are
   1.0416/1.0553/1.0481 (aggregate 1.0481). Rejected for these short-call costs,
   despite large-message CFB wins. `variants/threshold-inline/` retains all
   6528 raw rows, including all measured pairs and outliers.
   `threshold-inline-scalar.zig` is a subsequent test-only extension of the
   same production implementation; its extra tests are not the timing source.
3. **Separate noinline CFB scalar helper.**
   `variants/threshold-noinline-scalar.zig` routes short medium-register calls
   through a bounded scalar helper, leaving large-register dispatch alone.
   Two seeds per target on the shorter grid produce 1664 raw rows in
   `variants/noinline/`. Native IV4 split-15-byte ratios are 1.0770/1.1225;
   IV8 split-16-byte ratios are 1.0677/1.1050. Extra scalar separation costs
   more on these short calls. Rejected. A focused portable Debug run of this
   production implementation also verifies the expanded independent tests,
   including the direction-change reference, but is not final validation.
4. **Explicit full-block scalar CFB encryption.** `variants/vector-scalar.zig`
   finishes a pending partial block, uses explicit vector XOR/full feedback
   stores for sequential whole blocks, then uses the original partial tail.
   This is an algorithm/code-generation experiment rather than an inlining
   hint. `variants/vector-scalar/` keeps 1664 raw rows. Native IV2 split-16-byte
   medians are 1.0978/1.0763; IV3 split-1-byte medians 1.1040/1.1044. Rejected.
5. **Dispatch inside the CFB block-start state.**
   `variants/inside-dispatch.zig` keeps public medium encrypt routed through
   crypt(false), finishing pending feedback in the scalar loop and dispatching
   only at the next complete-block boundary. Existing large-register dispatch
   is unchanged. This changes dispatcher placement/control flow rather than
   adding force-inline/branch-likelihood hints. `variants/inside-dispatch/`
   retains 1664 raw rows. Native IV2 split-15-byte medians 1.0640/1.0700 and
   IV31 split-15-byte medians 1.0985/1.0524 remain costly. Rejected.
6. **CBC-only range trial.** Restore the CFB production section byte-for-byte from
   v0.9.2. Retain CBC IV>=2, conservative IV2 dispatch 128, IV3 dispatch/loop48,
   other dispatch/loop64, and bounded min(64,iv_blocks) scratch. Existing
   CBC64/65/128 helpers have exactly the same buffer bounds and thresholds;
   IV1 and every CFB/OFB/CMAC production line are unchanged. `variants/cbc-range-final/` has the
   full six-run range matrix: 6528 rows / 58752 measured pairs. Its validation is in `variants/cbc-range-validation/`.
7. **Explicit measured-width selector.** Keep the same CBC algorithm and
   thresholds, but enable only medium widths 2/3/4/8/16/24/31/32/63, preserving
   scalar encryption for every other medium width. This compile-time selector
   preserves the measured instances while satisfying the measured-class limit.
   Re-run the entire timing and validation matrix from this exact source; add
   negative eligibility controls at 5/7/9/15/17/23/25/30/33/62. The final source
   is `classic-retained.zig`, final timing is `final/`, and final independent
   validation is `validation/`. Timing conclusions never use test duration.

Short-call CFB code generation is sensitive to whether LLVM incorporates its
scalar body into the API caller. Assembly/nm captures preserve final and two
rejected dispatcher configurations in both compiler targets. Those captures
use explicit exported wrappers, so their symbol sizes describe those wrappers,
not an assertion that every benchmark instantiation has the same call graph.
`paired-native-forward` from the inline-scalar trial had a separate 0x2f4-byte
CFB8 encrypt body plus a 0x993-byte batch helper, whereas the unchanged
baseline scalar API was incorporated into its run body. The final CFB
production section is restored, avoiding that new entry dispatcher altogether.

No fresh IV65 CFB batching was enabled. The earlier all-large-width rejection
remains valid background, and the new medium experiments did not find a
short-call-stable CFB dispatcher to extend to irregular large rings. No public
API, Cipher kernel, context field/layout, external key cache or other mode
was changed. No push, PR, tag or release was performed.
