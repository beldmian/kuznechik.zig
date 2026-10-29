# Change: Add and optimize RFC cipher modes

## Why

The user explicitly requested implementing and optimizing all Kuznechik cipher modes described by the applicable RFCs, with incremental GitHub commits and releases. The library currently exposes raw block operations only.

## What Changes

- Add byte-oriented ECB, CTR, CBC, CFB, OFB, CMAC/OMAC, GCM, and MGM primitives.
- Include generic RFC 3610 CCM and RFC 7253 OCB, and reusable RFC 9189/9337
  cipher/key-wrap compositions identified by the RFC coverage audit.
- Add RFC 9367 and RFC 9227 MGM cipher-profile helpers with caller-derived leaf
  keys, precise nonce/tag/length rules, and explicit external KDF dependencies.
- Add the RFC 8645 ACPKM and ACPKM-Master encryption/authentication constructions, preserving specified counters, re-keying boundaries, and limits.
- Use accelerated independent-block operations where the mode permits parallelism.
- Verify authoritative vectors, chunked operation, malformed inputs, limits, authentication failures, and output preservation.
- Publish validated changes as incremental commits and releases.

## Impact

- Affected specs: cipher-modes (new).
- Affected code: new src/modes modules and public exports, tests, benchmarks, and documentation.
- Authorization: the user's explicit implementation and publication request authorizes this change. No existing single-block API or Cipher layout change is required.
