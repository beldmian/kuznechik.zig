---
id: i-9xu3
title: Implement key schedule validation fuzzer harness
priority: 2
created_at: '2026-01-21 22:28:29'
relationships:
  - from_id: i-9xu3
    from_uuid: c29c9720-31b9-40e7-a74c-327ac8f63a7b
    from_type: issue
    to_id: i-56qm
    to_uuid: ffb1026b-b9f2-4649-b491-32364576b099
    to_type: issue
    relationship_type: related
    created_at: '2026-01-21 22:31:44'
    metadata: null
  - from_id: i-9xu3
    from_uuid: c29c9720-31b9-40e7-a74c-327ac8f63a7b
    from_type: issue
    to_id: s-5kmc
    to_uuid: b7898187-e871-4a0e-a923-e001acbcb464
    to_type: spec
    relationship_type: implements
    created_at: '2026-01-21 22:31:44'
    metadata: null
status: closed
closed_at: '2026-01-21 22:55:17'
---
## Overview
Implement a fuzz harness that validates the key schedule generation.

## Acceptance Criteria
- Create `test/fuzz/key_schedule.zig` with a harness function
- Harness accepts 32-byte key as input
- Calls `make_iter_keys()` to generate round keys
- Asserts all 10 round keys are unique (no duplicates)
- Asserts no round key is all zeros
- Uses AFL++ compatible signature

## Implementation Notes
- Input format: bytes[0..32] = key
- Use `make_iter_keys()` function from kuznechik module
- Check uniqueness by comparing all pairs of round keys
- Check for zero keys with simple loop

## Related
- Implements spec [[s-5kmc]] requirement "Fuzz Harness Functions"
- Parent issue: [[i-56qm]]
