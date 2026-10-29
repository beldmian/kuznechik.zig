#!/bin/sh
set -eu
cd /home/user/kuz-gfni-memory
for v in candidate explicit-clobber explicit-read; do
 for seed in 944001 944002; do
  taskset -c 0 ./pairs-$v-forward "$seed" 31 1048576 > "$v-forward-$seed.jsonl" 2>&1
 done
 taskset -c 0 ./pairs-$v-reverse 944003 31 1048576 > "$v-reverse-944003.jsonl" 2>&1
 taskset -c 0 ./pairs-$v-portable 944004 15 131072 > "$v-portable-944004.jsonl" 2>&1
 echo "measured $v"
done
