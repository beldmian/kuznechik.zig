# v0.9.1 integration receipt

Root integrates author commit `b988f99aad791470a9f6ef0282308dc4de2155dd`
over released v0.9.0. Only OCB schedule initialization and its supporting tests
change in library source. Every current source file matches the author's Boat
manifest; `verify-artifacts.py` also checks every baseline source file against
the exact v0.9.0 Git commit, and both measured module snapshots and drivers.

For maximum full-block count m across AAD and payload, the largest accessible
schedule index is floor(log2(m)). Initializing bit_length(m) entries suffices;
zero full blocks use none. Partial blocks use L-star. The existing validation
bound permits at most 2^48 blocks, so all accessible indices fit L0 through L48.
Root source review confirmed both passes of opening use the same initialized
schedule, and validation and alias checks still precede setup or payload writes.

The [author report](../../performance/2026-10-29/ocb-schedule/report.md) records:

- Native ReleaseSafe/ReleaseFast: **101/101 tests** each.
- Native Debug: **93 passes, three backend skips**, 96 entries.
- Explicit portable x86-64 Debug/ReleaseSafe/ReleaseFast: **93 passes, two
  expected GFNI skips**, 95 entries each.
- A linked AArch64 test executable, compile evidence only.
- All existing RFC OCB tuples, aggregate checksums, 394 OpenSSL cases and
  2,208 guarded Kuznechik cases, plus 280 new independent boundary cases.

Root reran portable ReleaseSafe and the standard ReleaseSafe build test in
separate disk-backed caches. `checks.json` records exits and the test inventory;
logs are retained alongside it. Formatting and diff checks also pass.
Source verification binds these checks to the native and portable author logs;
metadata-only version/changelog changes follow those functional checks.

The [paired results](../../performance/2026-10-29/ocb-schedule/results.md)
retain every seed, layout and control. Some large calls have subpercent costs;
the optimization is retained for sustained short-message and record gains.
No aggregate or universal improvement is claimed for every workload. Exact
timing boundaries, hardware/compiler identities, sources, raw CSV and
reproduction scripts are preserved with the report. The assigned Boat VM
`bx_amh62u9b` was deleted after collecting its evidence.

These are finite correctness and performance checks. They do not prove physical
optimality or establish a registered Kuznechik OCB protocol profile.
