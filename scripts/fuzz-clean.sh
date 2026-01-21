#!/usr/bin/env bash
# Helper script to clean up fuzzing output directories
# Removes crash files, hangs, and queue to start fresh

set -e

OUTPUT_BASE="test/fuzz/output"

if [ ! -d "$OUTPUT_BASE" ]; then
    echo "No fuzzing output directory found: $OUTPUT_BASE"
    exit 0
fi

echo "This will remove all fuzzing output directories."
echo ""
echo "Directories to be removed:"
find "$OUTPUT_BASE" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
    echo "  $(basename "$dir")"
done
echo ""
read -p "Are you sure? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo "Cleaning fuzzing output directories..."

# Remove all output directories
rm -rf "${OUTPUT_BASE:?}"/*

echo "Done! Fuzzing output has been cleaned."
