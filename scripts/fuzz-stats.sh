#!/usr/bin/env bash
# Helper script to show AFL++ statistics for all running or completed fuzzing sessions

set -e

OUTPUT_BASE="test/fuzz/output"

if [ ! -d "$OUTPUT_BASE" ]; then
    echo "No fuzzing output directory found: $OUTPUT_BASE"
    exit 1
fi

echo "AFL++ Fuzzing Statistics"
echo "========================"
echo ""

# Find all fuzzer_stats files
find "$OUTPUT_BASE" -name "fuzzer_stats" -type f | sort | while read -r stats_file; do
    # Extract directory name
    dir_name=$(dirname "$stats_file")
    session_name=$(basename "$(dirname "$dir_name")")
    instance_name=$(basename "$dir_name")

    echo "Session: ${session_name} / Instance: ${instance_name}"
    echo "  Path: ${dir_name}"

    # Extract key statistics
    if [ -f "$stats_file" ]; then
        run_time=$(grep "^run_time :" "$stats_file" | cut -d: -f2 | xargs)
        execs_per_sec=$(grep "^execs_per_sec :" "$stats_file" | cut -d: -f2 | xargs)
        unique_crashes=$(grep "^unique_crashes :" "$stats_file" | cut -d: -f2 | xargs)
        saved_crashes=$(grep "^saved_crashes :" "$stats_file" | cut -d: -f2 | xargs)
        saved_hangs=$(grep "^saved_hangs :" "$stats_file" | cut -d: -f2 | xargs)
        cur_path=$(grep "^cur_path :" "$stats_file" | cut -d: -f2 | xargs)

        # Convert run_time to human-readable
        if [ -n "$run_time" ] && [ "$run_time" -gt 0 ] 2>/dev/null; then
            hours=$((run_time / 3600))
            minutes=$(((run_time % 3600) / 60))
            seconds=$((run_time % 60))
            run_time_formatted=$(printf "%02d:%02d:%02d" $hours $minutes $seconds)
        else
            run_time_formatted="N/A"
        fi

        echo "  Runtime: ${run_time_formatted}"
        echo "  Speed: ${execs_per_sec} exec/sec"
        echo "  Coverage: ${cur_path} paths"
        echo "  Crashes: ${unique_crashes} unique, ${saved_crashes} saved"
        echo "  Hangs: ${saved_hangs}"

        # Count actual crash files
        crash_dir=$(dirname "$stats_file")/crashes
        if [ -d "$crash_dir" ]; then
            crash_count=$(find "$crash_dir" -type f | wc -l | xargs)
            echo "  Crash files: ${crash_count}"
        fi

        # Show if still running
        if pgrep -f "afl-fuzz.*$(basename "$(dirname "$(dirname "$stats_file")")")" >/dev/null 2>&1; then
            echo "  Status: RUNNING"
        else
            echo "  Status: STOPPED"
        fi
    fi

    echo ""
done

# Show afl-whatsup summary if available
if command -v afl-whatsup &> /dev/null; then
    echo "Real-time Summary (afl-whatsup):"
    echo "--------------------------------"
    for session_dir in "$OUTPUT_BASE"/*/; do
        if [ -d "$session_dir" ]; then
            afl-whatsup "$session_dir" 2>/dev/null || true
        fi
    done
fi
