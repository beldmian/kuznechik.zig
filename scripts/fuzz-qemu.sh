#!/usr/bin/env bash
# Helper script to run AFL++ in QEMU mode (binary instrumentation)
# Recommended for Zig programs - requires AFL++ built with QEMU support

set -e

FUZZER="${1:-ls_roundtrip}"
case "$FUZZER" in
    roundtrip) BUILD_STEP=fuzz-round-trip; CORPUS_NAME=round_trip ;;
    key_schedule) BUILD_STEP=fuzz-key-schedule; CORPUS_NAME=key_schedule ;;
    ls_roundtrip) BUILD_STEP=fuzz-ls-roundtrip; CORPUS_NAME=ls_roundtrip ;;
    *) echo "Unknown fuzzer: $FUZZER" >&2; exit 1 ;;
esac
CORPUS_DIR="test/fuzz/corpus/${CORPUS_NAME}"
OUTPUT_DIR="test/fuzz/output/${FUZZER}_qemu"
BINARY="./zig-out/bin/${FUZZER}"

# AFL diagnoses a missing afl-qemu-trace when starting. Its help advertises
# -Q even on installations without that runtime, so help text is not a probe.

# Check if fuzzer exists
if [ ! -f "$BINARY" ]; then
    echo "Building fuzzer: ${FUZZER}"
    zig build "$BUILD_STEP"
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
