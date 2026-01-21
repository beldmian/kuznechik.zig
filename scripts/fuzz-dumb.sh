#!/usr/bin/env bash
# Helper script to run AFL++ in dumb mode (no instrumentation required)
# This is the simplest mode that works with any binary

set -e

FUZZER="${1:-ls_roundtrip}"
CORPUS_DIR="test/fuzz/corpus/${FUZZER}"
OUTPUT_DIR="test/fuzz/output/${FUZZER}_dumb"
BINARY="./zig-out/bin/${FUZZER}"

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

echo "Starting AFL++ dumb mode for ${FUZZER}"
echo "  Corpus: ${CORPUS_DIR}"
echo "  Output: ${OUTPUT_DIR}"
echo "  Binary: ${BINARY}"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Run AFL++ in dumb mode
afl-fuzz -n \
    -i "$CORPUS_DIR" \
    -o "$OUTPUT_DIR" \
    -- "$BINARY"
