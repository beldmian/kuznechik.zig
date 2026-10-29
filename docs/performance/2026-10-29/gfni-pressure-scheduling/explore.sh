#!/bin/sh
set -eu
cd /home/user/kuz-gfni-pressure
for v in candidate ready00 ready12 ready18 ready19; do
 taskset -c 0 ./pairs-"$v" 902901 9 262144 > "explore-$v-902901.jsonl" 2>&1
 echo "timed $v"
done
