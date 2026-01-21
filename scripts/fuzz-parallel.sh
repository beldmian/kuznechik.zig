#!/usr/bin/env bash
# Helper script to run multiple AFL++ instances in parallel
# This provides better coverage by using different mutation strategies

set -e

FUZZER="${1:-ls_roundtrip}"
MODE="${2:-dumb}"  # Options: dumb, qemu
NUM_INSTANCES="${3:-3}"

CORPUS_DIR="test/fuzz/corpus/${FUZZER}"
OUTPUT_DIR="test/fuzz/output/${FUZZER}_parallel_${MODE}"
BINARY="./zig-out/bin/${FUZZER}"

# Set AFL flags based on mode
if [ "$MODE" = "qemu" ]; then
    AFL_FLAG="-Q"
    if ! afl-fuzz -h 2>&1 | grep -q "\-Q"; then
        echo "Error: QEMU mode not available. Use 'dumb' mode instead."
        exit 1
    fi
else
    AFL_FLAG="-n"
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
    exit 1
fi

echo "Starting ${NUM_INSTANCES} parallel AFL++ instances (${MODE} mode) for ${FUZZER}"
echo "  Corpus: ${CORPUS_DIR}"
echo "  Output: ${OUTPUT_DIR}"
echo "  Binary: ${BINARY}"
echo ""
echo "Press Ctrl+C to stop all instances"
echo ""

# Kill any existing AFL instances on exit
trap 'pkill -f "afl-fuzz.*${FUZZER}" 2>/dev/null; echo "Stopped all instances"' EXIT

# Start master instance
echo "Starting master instance..."
afl-fuzz -M "master" ${AFL_FLAG} \
    -i "$CORPUS_DIR" \
    -o "$OUTPUT_DIR" \
    -- "$BINARY" &

MASTER_PID=$!

# Wait a moment for master to initialize
sleep 2

# Start secondary instances
for i in $(seq 2 $NUM_INSTANCES); do
    NAME="fuzzer$(printf "%02d" $i)"
    echo "Starting secondary instance: ${NAME}..."

    afl-fuzz -S "${NAME}" ${AFL_FLAG} \
        -i "$CORPUS_DIR" \
        -o "$OUTPUT_DIR" \
        -- "$BINARY" &
done

echo ""
echo "All instances started. Monitor progress in: ${OUTPUT_DIR}"
echo "Master PID: ${MASTER_PID}"
echo ""
echo "View stats with:"
echo "  cat ${OUTPUT_DIR}/master/fuzzer_stats"
echo "  afl-whatsup ${OUTPUT_DIR}"
echo ""

# Wait for master process
wait $MASTER_PID
