## Implementation and publication

- [x] Audit applicable RFC constructions, parameter rules, and vectors.
- [x] Implement and test shared classic modes and CMAC.
- [x] Implement and test MGM and GCM authenticated encryption.
- [x] Implement and test generic RFC 3610 CCM and RFC 7253 OCB.
- [x] Implement and test every RFC 8645 cipher-mode construction, including master-key variants.
- [x] Implement and test reusable CTR-OMAC and KExp15/KImp15 compositions; record protocol key-schedule dependencies explicitly.
- [x] Implement and test RFC 9367/9227 MGM cipher-profile helpers with caller-derived keys and documented external protocol dependencies.
- [x] Benchmark serial and batch paths on Boat and retain measured improvements.
- [x] Document APIs, RFC scope, limits, and reproducible results.
- [x] Publish verified increments with commits and releases.

## Closeout — 2026-10-29

Released byte-oriented coverage and external protocol responsibilities are listed
in [RFC-MODES.md](../../../../docs/RFC-MODES.md). Additional streaming and bit-level
API decisions are tracked in [#7](https://github.com/beldmian/kuznechik.zig/issues/7).
Historical validation and reviews remain in the research archive.
