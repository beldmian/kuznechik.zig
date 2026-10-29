#!/usr/bin/env bash
set -euo pipefail
# Run from the isolated source root on the owned Boat VM. All caches are disk
# backed, unique to this experiment. No credentials or environment import.
ZIG=${ZIG:-../toolchain/zig}
E=docs/performance/2026-10-29/classic-feedback
mkdir -p ../cache/verified8-global ../cache/verified8-portable-global
"$ZIG" version > ../retained-compiler.log
"$ZIG" env >> ../retained-compiler.log
sha256sum "$ZIG" >> ../retained-compiler.log
find src -type f -print0 | sort -z | xargs -0 sha256sum > ../retained-source-sha256.txt
sha256sum "$E/paired.zig" "$E/classic-before.zig" >> ../retained-source-sha256.txt
for target in native portable; do
    cpu=native
    global=../cache/verified8-global
    if [[ $target == portable ]]; then cpu=x86_64; global=../cache/verified8-portable-global; fi
    "$ZIG" test src/kuznechik.zig -O ReleaseSafe -mcpu="$cpu" --cache-dir "../cache/verified8-tests-$target" --global-cache-dir "$global" > "../retained-tests-$target.log" 2>&1
    "$ZIG" build-exe -O ReleaseFast -mcpu="$cpu" --cache-dir "../cache/verified8-bench-$target" --global-cache-dir "$global" --dep kuz --dep before -Mroot="$E/paired.zig" -Mkuz=src/kuznechik.zig -Mbefore="$E/classic-before.zig" -femit-bin="../paired-retained-$target"
    budget=1048576
    if [[ $target == portable ]]; then budget=131072; fi
    taskset -c 0 "../paired-retained-$target" 123 "$budget" 99 0 > "../retained-$target-123.jsonl" 2>&1
    taskset -c 0 "../paired-retained-$target" 456 "$budget" 99 3 > "../retained-$target-456.jsonl" 2>&1
    sha256sum "../paired-retained-$target" >> ../retained-binary-sha256.txt
    # Swap the first-mentioned nominal types, changing function instantiation
    # order, and reverse the interpretation of before/after in analysis.
    sed -e 's/const Before = @import("before").Modes(kuz.Cipher);/const Before = kuz.modes.classic;/' -e 's/const After = kuz.modes.classic;/const After = @import("before").Modes(kuz.Cipher);/' "$E/paired.zig" > "$E/paired-reversed.zig"
    "$ZIG" build-exe -O ReleaseFast -mcpu="$cpu" --cache-dir "../cache/verified8-reversed-$target" --global-cache-dir "$global" --dep kuz --dep before -Mroot="$E/paired-reversed.zig" -Mkuz=src/kuznechik.zig -Mbefore="$E/classic-before.zig" -femit-bin="../paired-reversed-$target"
    taskset -c 0 "../paired-reversed-$target" 789 "$budget" 99 1 > "../reversed-$target-789.jsonl" 2>&1
    sha256sum "../paired-reversed-$target" >> ../retained-binary-sha256.txt
    mv "$E/paired-reversed.zig" "../retained-reversed-$target.zig"
done

"$ZIG" test src/kuznechik.zig -O ReleaseFast -mcpu=native --cache-dir ../cache/verified8-fast-native --global-cache-dir ../cache/verified8-global > ../retained-tests-native-fast.log 2>&1
"$ZIG" build-exe -O ReleaseSafe --cache-dir ../cache/verified8-contract --global-cache-dir ../cache/verified8-global --dep kuz --dep before -Mroot="$E/contracts.zig" -Mkuz=src/kuznechik.zig -Mbefore="$E/classic-before.zig" -femit-bin=../retained-contract
../retained-contract > ../retained-contract.log 2>&1
