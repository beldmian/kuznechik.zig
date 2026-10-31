#!/usr/bin/env bash
# Helper script to run multiple AFL++ instances in parallel
# QEMU workers synchronize; dumb workers run independently.

set -e

FUZZER="${1:-ls_roundtrip}"
MODE="${2:-dumb}"  # Options: dumb, qemu
NUM_INSTANCES="${3:-3}"

case "$FUZZER" in
    roundtrip) BUILD_STEP=fuzz-round-trip; CORPUS_NAME=round_trip ;;
    key_schedule) BUILD_STEP=fuzz-key-schedule; CORPUS_NAME=key_schedule ;;
    ls_roundtrip) BUILD_STEP=fuzz-ls-roundtrip; CORPUS_NAME=ls_roundtrip ;;
    *) echo "Unknown fuzzer: $FUZZER" >&2; exit 1 ;;
esac
CORPUS_DIR="test/fuzz/corpus/${CORPUS_NAME}"
OUTPUT_DIR="test/fuzz/output/${FUZZER}_parallel_${MODE}"
BINARY="./zig-out/bin/${FUZZER}"

case "$MODE" in
    dumb|qemu) ;;
    *) echo "Unknown mode: $MODE (expected dumb or qemu)" >&2; exit 1 ;;
esac
if ! [[ "$NUM_INSTANCES" =~ ^[1-9][0-9]*$ ]]; then
    echo "Instance count must be a positive integer" >&2
    exit 1
fi

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
    exit 1
fi

echo "Starting ${NUM_INSTANCES} parallel AFL++ instances (${MODE} mode) for ${FUZZER}"
echo "  Corpus: ${CORPUS_DIR}"
echo "  Output: ${OUTPUT_DIR}"
echo "  Binary: ${BINARY}"
echo ""
echo "Press Ctrl+C to stop all instances"
echo ""

# Stop only the background jobs started by this script.
cleanup() {
    local pid
    for pid in $(jobs -pr); do kill "$pid" 2>/dev/null || true; done
    wait 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

PIDS=()
for ((i=1; i<=NUM_INSTANCES; i++)); do
    NAME="fuzzer$(printf "%02d" "$i")"
    if [ "$MODE" = qemu ]; then
        # Instrumented workers can share an AFL synchronization directory.
        if [ "$i" -eq 1 ]; then ROLE=-M; else ROLE=-S; fi
        afl-fuzz -Q "$ROLE" "$NAME" -i "$CORPUS_DIR" -o "$OUTPUT_DIR" -- "$BINARY" &
    else
        # AFL rejects -M/-S in dumb mode; keep independent worker directories.
        afl-fuzz -n -i "$CORPUS_DIR" -o "$OUTPUT_DIR/$NAME" -- "$BINARY" &
    fi
    PIDS+=("$!")
done

for pid in "${PIDS[@]}"; do wait "$pid"; done
