#!/usr/bin/env bash
# Helper script to reproduce crashes found by AFL++
# Usage: ./scripts/fuzz-reproduce.sh <fuzzer_name> <crash_file>

set -e

FUZZER="${1:-ls_roundtrip}"
CRASH_FILE="$2"
BINARY="./zig-out/bin/${FUZZER}"

if [ -z "$CRASH_FILE" ]; then
    echo "Usage: $0 <fuzzer_name> <crash_file>"
    echo ""
    echo "Examples:"
    echo "  $0 ls_roundtrip test/fuzz/output/ls_roundtrip_dumb/default/crashes/id:000000,sig:06,src:000001,op:havoc,rep:2"
    echo ""
    echo "Listing recent crashes for ${FUZZER}:"
    echo ""
    find "test/fuzz/output" -name "id:*,sig:*" -type f 2>/dev/null | head -10 | while read -r crash; do
        echo "  $crash"
    done
    exit 1
fi

if [ ! -f "$CRASH_FILE" ]; then
    echo "Error: Crash file not found: $CRASH_FILE"
    exit 1
fi

echo "Reproducing crash with ${FUZZER}"
echo "  Crash file: ${CRASH_FILE}"
echo "  Binary: ${BINARY}"
echo ""
echo "Running..."

# Run with the crash file as input
"$BINARY" < "$CRASH_FILE" || true

EXIT_CODE=$?

echo ""
echo "Exit code: $EXIT_CODE"

# Decode signal if available
if [[ "$CRASH_FILE" =~ sig:([0-9]+) ]]; then
    SIGNAL="${BASH_REMATCH[1]}"
    echo "Crash signal: ${SIGNAL}"
    case $SIGNAL in
        6)  echo "  SIGABRT - Abort (usually assertion failure)" ;;
        11) echo "  SIGSEGV - Segmentation fault" ;;
        4)  echo "  SIGILL - Illegal instruction" ;;
        8)  echo "  SIGFPE - Floating point exception" ;;
        *)  echo "  Unknown signal" ;;
    esac
fi
