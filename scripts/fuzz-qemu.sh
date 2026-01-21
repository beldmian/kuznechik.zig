#!/usr/bin/env bash
# Helper script to run AFL++ in QEMU mode (binary instrumentation)
# Recommended for Zig programs - requires AFL++ built with QEMU support

set -e

FUZZER="${1:-ls_roundtrip}"
CORPUS_DIR="test/fuzz/corpus/${FUZZER}"
OUTPUT_DIR="test/fuzz/output/${FUZZER}_qemu"
BINARY="./zig-out/bin/${FUZZER}"

# Check if afl-fuzz supports QEMU mode
if ! afl-fuzz -h 2>&1 | grep -q "\-Q"; then
    echo "Error: AFL++ QEMU mode not available."
    echo ""
    echo "Your AFL++ installation doesn't support QEMU mode."
    echo "This is common with Homebrew installations."
    echo ""
    echo "Options:"
    echo "  1. Use dumb mode instead: ./scripts/fuzz-dumb.sh ${FUZZER}"
    echo "  2. Build AFL++ from source with QEMU support:"
    echo "     git clone https://github.com/AFLplusplus/AFLplusplus"
    echo "     cd AFLplusplus && make all && sudo make install"
    exit 1
fi

# Check if fuzzer exists
if [ ! -f "$BINARY" ]; then
    echo "Building fuzzer: ${FUZZER}"
    zig build "fuzz-${FUZZER}"
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check if corpus exists
if [ ! -d "$CORPUS_DIR" ]; then
    echo "Error: Corpus directory not found: $CORPUS_DIR"
    echo "Available corpus directories:"
    ls -d test/fuzz/corpus/*/ 2>/dev/null || echo "  None"
    exit 1
fi

echo "Starting AFL++ QEMU mode for ${FUZZER}"
echo "  Corpus: ${CORPUS_DIR}"
echo "  Output: ${OUTPUT_DIR}"
echo "  Binary: ${BINARY}"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Run AFL++ in QEMU mode
afl-fuzz -Q \
    -i "$CORPUS_DIR" \
    -o "$OUTPUT_DIR" \
    -- "$BINARY"
