#!/bin/bash
# ============================================================================
# A 线自检：确认"编译过程 + LLVM IR"这条流水线在本机可用
#   用法（在仓库根目录）：bash tools/check_laneA.sh
#   成功标准：末尾两行 case1 PASS / case2 PASS
# ============================================================================
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT" || exit 1
SAND="${SAND:-$(dirname "$ROOT")/[B]sandbox}"
OUT="$SAND/laneA"
rm -rf "$OUT" && mkdir -p "$OUT"

echo "=== clang 版本 ==="
clang --version | head -1

echo
echo "=== [1] 预处理 -E：宏展开 + 头文件插入 ==="
clang -E common/sysy_main.c -o "$OUT/main.i"
echo "源文件 $(wc -l < common/sysy_main.c) 行  ->  预处理后 $(wc -l < "$OUT/main.i") 行"
if grep -q "SQUARE\|SCALE" "$OUT/main.i"; then
  echo "注意：宏名仍出现在 .i 中，检查是否只在注释/字符串里"
else
  echo "OK：SCALE / SQUARE 宏已全部展开"
fi

echo
echo "=== [2] 词法分析 -dump-tokens（前 3 行）==="
clang -E -Xclang -dump-tokens common/sysy_main.c 2>&1 | head -3

echo
echo "=== [3] 语法分析 -ast-dump（前 3 行）==="
clang -E -Xclang -ast-dump common/sysy_main.c 2>&1 | head -3

echo
echo "=== [4] 中间代码生成（LLVM IR）==="
clang -S -emit-llvm -O0 common/sysy_main.c -o "$OUT/main_O0.ll"
clang -S -emit-llvm -O2 common/sysy_main.c -o "$OUT/main_O2.ll"
echo "O0: $(wc -l < "$OUT/main_O0.ll") 行   O2: $(wc -l < "$OUT/main_O2.ll") 行"

echo
echo "=== [5] opaque pointer 检查（clang 21 默认）==="
echo "含 ptr  的行数: $(grep -c 'ptr' "$OUT/main_O0.ll")"
echo "含 i32* 的行数: $(grep -c 'i32\*' "$OUT/main_O0.ll")   <- 期望为 0"

echo
echo "=== [6] .ll <-> .bc 往返 + 语法校验 ==="
clang -c -emit-llvm -O0 common/sysy_main.c -o "$OUT/main.bc"
llvm-dis "$OUT/main.bc" -o "$OUT/roundtrip.ll" && echo "llvm-dis OK"
llvm-as "$OUT/roundtrip.ll" -o /dev/null && echo "llvm-as OK（IR 语法合法）"

echo
echo "=== [7] 代码优化 pass ==="
opt -passes='mem2reg,instcombine,simplifycfg' -S "$OUT/main_O0.ll" -o "$OUT/main_opt.ll" \
  && echo "opt OK: $(wc -l < "$OUT/main_opt.ll") 行"

echo
echo "=== [8] 代码生成 llc -> x86 汇编 ==="
llc "$OUT/main.bc" -o "$OUT/main_llc.s" && echo "llc OK: $(wc -l < "$OUT/main_llc.s") 行"

echo
echo "=== [9] 链接 + 运行验证 ==="
if [ -f A-llvm/libsysy/libsysy_x86.a ]; then
  clang -O0 -o "$OUT/main_x86" "$OUT/main_O0.ll" -L A-llvm/libsysy -lsysy_x86
  echo "使用课程提供的 libsysy_x86.a"
else
  cat > "$OUT/stub.c" <<'EOF'
#include <stdio.h>
int  getint(void){ int x; if (scanf("%d",&x)!=1) return 0; return x; }
void putint(int x){ printf("%d", x); }
void putch(int c){ putchar(c); }
EOF
  clang -O0 -o "$OUT/main_x86" "$OUT/main_O0.ll" "$OUT/stub.c"
  echo "未找到 libsysy_x86.a，改用等价桩函数（报告里注明即可）"
fi
for c in case1 case2; do
  # 注意：$OUT 是绝对路径，不能再加 "./" 前缀
  if "$OUT/main_x86" < "common/testdata/$c.in" | diff -q - "common/expected/$c.out" >/dev/null; then
    echo "$c PASS"
  else
    echo "$c FAIL"; "$OUT/main_x86" < "common/testdata/$c.in" | diff - "common/expected/$c.out"
  fi
done
