# Tracked follow-up work

Remaining work is recorded in repository issues:

- [#3 — AFL input delivery and runner/build naming](https://github.com/beldmian/kuznechik.zig/issues/3).
- [#4 — Valid key-schedule fuzz oracles](https://github.com/beldmian/kuznechik.zig/issues/4).
- [#5 — Short-call CBC costs and CFB batching dispatch](https://github.com/beldmian/kuznechik.zig/issues/5).
- [#6 — Multi-target CI, native AArch64 and build-memory coverage](https://github.com/beldmian/kuznechik.zig/issues/6).
- [#7 — Streaming and bit-level mode API decisions](https://github.com/beldmian/kuznechik.zig/issues/7).
- [#8 — An explicit constant-time cipher policy](https://github.com/beldmian/kuznechik.zig/issues/8).

- [#9 — Remaining GFNI kernel hypotheses](https://github.com/beldmian/kuznechik.zig/issues/9).

The audited byte-oriented mode families are implemented. Protocol key derivation,
framing, replay state and cumulative key-use accounting remain documented caller
responsibilities. The performance evidence is finite and does not prove physical
optimality.
