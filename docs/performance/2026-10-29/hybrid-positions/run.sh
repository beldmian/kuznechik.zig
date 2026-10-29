#!/bin/bash
# Reproduce initial finite search on an idle Zen5 host, with Zig0.15.1.
# Source-only snapshots; no checkout mutation. Stage must be disk-backed.
set -euo pipefail
receipt_dir=$(cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(git -C "$receipt_dir" rev-parse --show-toplevel)
stage_dir=${1:?Supply a fresh disk-backed stage directory}
python3 "$receipt_dir/prepare.py" "$repo_dir" "$stage_dir"
python3 "$receipt_dir/screen.py" "$stage_dir"
cd "$stage_dir"
bash "$receipt_dir/build.sh"
bash "$receipt_dir/explore.sh"
python3 "$receipt_dir/codegen.py" "$stage_dir" > codegen.json
python3 "$receipt_dir/analyze.py" "$stage_dir"
