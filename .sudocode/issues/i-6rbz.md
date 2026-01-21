---
id: i-6rbz
title: Fuzzing doesn't work because binaries require instrumentation.
priority: 0
created_at: '2026-01-21 23:10:32'
relationships:
  - from_id: i-6rbz
    from_uuid: c1ec394d-1f11-42cf-b173-13a667989869
    from_type: issue
    to_id: s-5kmc
    to_uuid: b7898187-e871-4a0e-a923-e001acbcb464
    to_type: spec
    relationship_type: blocks
    created_at: '2026-01-21 23:13:13'
    metadata: null
status: closed
closed_at: '2026-01-21 23:20:09'
---
afl-fuzz -i test/fuzz/corpus/transformations -o test/fuzz/output/transformations -- ./zig-out/bin/ls_roundtrip

afl-fuzz++4.35c based on afl by Michal Zalewski and a large online community
[+] AFL++ is maintained by Marc "van Hauser" Heuse, Dominik Maier, Andrea Fioraldi and Heiko "hexcoder" Eißfeldt
[+] AFL++ is open source, get it at https://github.com/AFLplusplus/AFLplusplus
[+] NOTE: AFL++ >= v3 has changed defaults and behaviours - see README.md
[+] No -M/-S set, autoconfiguring for "-S default"
[*] Getting to work...
[+] Using exploration-based constant power schedule (EXPLORE)
[+] Enabled testcache with 50 MB
[+] Generating fuzz data with a length of min=1 max=1048576
[*] Checking CPU scaling governor...
[!] WARNING: Could not check CPU min frequency
[+] You have 8 CPU cores and 3 runnable tasks (utilization: 38%).
[+] Try parallel jobs - see /opt/homebrew/Cellar/afl++/4.35c/share/doc/afl/fuzzing_in_depth.md#c-using-multiple-cores
[*] Setting up output directories...
[+] Output directory exists but deemed OK to reuse.
[*] Deleting old session data...
[+] Output dir cleanup successful.
[*] Validating target binary...

[-] Looks like the target binary is not instrumented! The fuzzer depends on
    compile-time instrumentation to isolate interesting test cases while
    mutating the input data. For more information, and for tips on how to
    instrument binaries, please see /opt/homebrew/Cellar/afl++/4.35c/share/doc/afl/README.md.

    When source code is not available, you may be able to leverage QEMU
    mode support. Consult the README.md for tips on how to enable this.

    If your target is an instrumented binary (e.g. with zafl, retrowrite,
    etc.) then set 'AFL_SKIP_BIN_CHECK=1'

    (It is also possible to use afl-fuzz as a traditional, non-instrumented
    fuzzer. For that use the -n option - but expect much worse results.)

[-] PROGRAM ABORT : No instrumentation detected
         Location : check_binary(), src/afl-fuzz-init.c:3259
