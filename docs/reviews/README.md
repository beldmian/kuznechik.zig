# Independent implementation reviews

Full reports, reviewed source hashes and independent check artifacts are in the
[research snapshot](https://github.com/beldmian/kuznechik.zig/tree/research-2026-10-29/docs/reviews) and
[downloadable archive](../performance/README.md).

- [MGM and RFC 8645 modes](https://github.com/beldmian/kuznechik.zig/blob/research-2026-10-29/docs/reviews/mgm-acpkm-independent-sol-20261029-0835.md): no blocking implementation defects found at the reviewed hashes.
- [OCB and RFC 9189/9337 compositions](https://github.com/beldmian/kuznechik.zig/blob/research-2026-10-29/docs/reviews/ocb-compositions-independent-sol-20261029.md): no blocking implementation defects found at the reviewed hashes.
- [RFC 9367/9227 MGM profiles](https://github.com/beldmian/kuznechik.zig/blob/research-2026-10-29/docs/reviews/mgm-profiles-independent-20261029.md): found a nonce-alias defect in multipart sealing. The nonce is captured before payload writes; the fix and regression checks shipped before v0.9.0. See the [resolution](https://github.com/beldmian/kuznechik.zig/blob/research-2026-10-29/docs/validation/v0.9.0/README.md).

Reviews cover the stated snapshots and finite independent checks. They are not
formal security proofs. Current limitations and further work are recorded in
[open work](../OPEN-WORK.md).
