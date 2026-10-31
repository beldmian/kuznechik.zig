# Tracked follow-up work

Status of the local issue follow-up, 2026-10-31. Repository issues remain open;
this file records implementation/evidence status without closing them.

| Issue | Delivered in this follow-up | Remaining acceptance work |
|---|---|---|
| [#3 — AFL input delivery](https://github.com/beldmian/kuznechik.zig/issues/3) | stdin/file adapter, separate smoke mode, consistent runner mapping, distinct/short input tests and a real brief dumb-mode campaign | No coverage or sustained campaign claim; QEMU runtime campaign not executed |
| [#4 — Key-schedule oracles](https://github.com/beldmian/kuznechik.zig/issues/4) | Independent scalar expansion checked against all RFC round keys; inverse linear keys and reverse Feistel groups; zero/equal-half regressions | No new correctness or security assurance beyond these checks |
| [#5 — CBC/CFB dispatch](https://github.com/beldmian/kuznechik.zig/issues/5) | Existing cipher/mode implementation retained | No new candidate or matched paired performance experiment; research remains open |
| [#6 — Multi-target validation](https://github.com/beldmian/kuznechik.zig/issues/6) | Reproducible matrix/CI, named inventories, isolated caches/resources; 11 x86-64 profiles passed on Zig 0.15.2/Zen 5 | Native AArch64 and actual hosted CI results still required; broader hardware claims remain unsupported |
| [#7 — API scope](https://github.com/beldmian/kuznechik.zig/issues/7) | Explicit decision in [RFC scope](RFC-MODES.md#decision-on-remaining-api-dimensions-issue-7) to retain byte APIs and defer streaming/bit-level extensions | No extension is claimed implemented; future opening APIs must preserve authentication before release |
| [#8 — Constant-time policy](https://github.com/beldmian/kuznechik.zig/issues/8) | Existing limitation remains documented | Explicit backend/policy covering setup and every payload size, assembly review and target validation are not implemented |
| [#9 — GFNI hypotheses](https://github.com/beldmian/kuznechik.zig/issues/9) | Existing kernels retained; correctness matrix passed | No new kernel candidate or paired performance evidence; research remains open |

See [fuzzing](FUZZING.md) and [validation receipts](validation/README.md).
The audited byte-oriented mode families are implemented. Protocol key derivation,
framing, replay state and cumulative key-use accounting remain caller
responsibilities. The performance evidence is finite and does not prove physical
optimality. New performance experiments and the constant-time policy are
unfinished work, not blocked by a claimed universal impossibility.
