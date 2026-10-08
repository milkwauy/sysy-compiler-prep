#!/bin/bash
# 校验：本机参考实现（C 版本）与冻结的期望输出必须逐字节一致
# 用法： bash common/verify_expected.sh
set -e
cd "$(dirname "$0")"
gcc -O0 -o ref sysy_main_ref.c
ok=1
for c in case1 case2; do
  if ./ref < "testdata/$c.in" | diff -q - "expected/$c.out" > /dev/null; then
    echo "$c PASS"
  else
    echo "$c FAIL"
    ./ref < "testdata/$c.in" | diff - "expected/$c.out" || true
    ok=0
  fi
done
rm -f ref
exit $((1 - ok))
