#!/bin/bash
set -e
cd "$(dirname "$0")"
gcc -O0 -o ref sysy_main_ref.c
for c in case1 case2; do
  echo "--- $c ---"
  ./ref < "testdata/$c.in"
  echo
done
