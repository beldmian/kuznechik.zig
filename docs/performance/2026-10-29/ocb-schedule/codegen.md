Generated-code observations (Zig 0.15.1 ReleaseFast)

| Target | Layout | runFirst address | runSecond address | Fixed-schedule initializer address |
|---|---|---|---|---|
| native | forward | 000000000104d8f0 | 000000000104f340 | 000000000104c6c0 |
| native | reverse | 000000000104d970 | 000000000104fa00 | 000000000104f700 |
| native | control | 000000000104d8f0 | 000000000104f340 | 000000000104c6c0 |
| x86_64 | forward | 0000000001044ac0 | 0000000001045e00 | 0000000001043ea0 |
| x86_64 | reverse | 0000000001044a10 | 0000000001046420 | 0000000001046040 |
| x86_64 | control | 0000000001044ac0 | 0000000001045e00 | 0000000001043ea0 |

The runtime-sized public API benchmark retains the baseline Schedule.init call. Its fixed loop initializes every L0..L48 entry and returns/copies the full 816-byte schedule. In the candidate, LLVM inlines setup into the public API call paths; the native disassembly includes lzcnt on the maximum full-block count, a zero-count bypass, and a loop bounded by that count. This is an observation for these actual compiled calls, not a claim that every conceivable statically sized caller retains the same work. The measured gain includes all code-generation effects of the bounded initializer; no separate microbenchmark gain is added.

Forward and reverse builds put the implementations at different addresses and exchange the benchmark slots. Baseline-versus-baseline controls retain distinct runFirst/runSecond bodies (and share identical fixed-setup code). Full disassemblies are retained as logs/disassembly-*.log.gz, with symbol maps alongside. Focused native excerpts are logs/baseline-native-schedule.asm and logs/candidate-native-schedule-excerpts.asm.
