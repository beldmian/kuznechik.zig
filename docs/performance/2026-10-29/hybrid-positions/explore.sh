#!/bin/bash
set -euo pipefail
# All builds must have completed before running. Logical CPU0, no other jobs.
for v in control prefix suffix high_prefix low_suffix edge_mix boundary outer split3 split2 spaced spaced_end even odd ends middle high_edges; do
 taskset -c 0 "./pairs-$v" 94101 15 262144 0 1 2> "explore-$v-94101.jsonl"
done
