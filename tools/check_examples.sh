#!/bin/bash
# ============================================================================
# 检查 common/examples/ 里的两个指导书示例程序能否正常编译（A/B 两条路都要能过）
# 临时输出写到仓库外面的 harness 辅助目录，不污染 git 工作树。
# ============================================================================
BASE="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$BASE" || exit 1
SAND="${SAND:-$(dirname "$BASE")/[B]sandbox}"
OUT="$SAND/check_examples"
rm -rf "$OUT" && mkdir -p "$OUT"

echo "=== 参考实现（用于得到真值）==="
cat > "$OUT/ref.c" <<'EOF'
#include <stdio.h>
static int  r_getint(void){ int x; if (scanf("%d",&x)!=1) return 0; return x; }
static void r_putint(int x){ printf("%d", x); }
static void r_putch(int c){ putchar(c); }
#define getint r_getint
#define putint r_putint
#define putch  r_putch
#include "EXAMPLEC"
#undef getint
#undef putint
#undef putch
EOF

for f in fact fib; do
  echo
  echo "########## $f.c ##########"
  sed "s|EXAMPLEC|$BASE/common/examples/$f.c|" "$OUT/ref.c" > "$OUT/ref_$f.c"
  gcc -O0 -o "$OUT/ref_$f" "$OUT/ref_$f.c" || { echo "!! 参考实现编译失败"; continue; }

  echo "--- A 路：clang 走 x86 ---"
  clang -O0 -c common/examples/$f.c -o "$OUT/${f}_x86.o" 2>&1 | head -3
  [ -f "$OUT/${f}_x86.o" ] && echo "  clang -c OK"
  clang -O0 -S -emit-llvm common/examples/$f.c -o "$OUT/$f.ll" 2>&1 | head -3
  [ -f "$OUT/$f.ll" ] && echo "  clang -emit-llvm OK: $(wc -l < "$OUT/$f.ll") 行"

  echo "--- B 路：交叉编译到 RISC-V ---"
  sed '/#include <stdio.h>/d' common/examples/$f.c > "$OUT/${f}_free.c"
  clang --target=riscv64-unknown-elf -O0 -S "$OUT/${f}_free.c" -o "$OUT/${f}_riscv.s" 2>&1 | head -3
  [ -f "$OUT/${f}_riscv.s" ] && echo "  clang --target=riscv64 OK: $(wc -l < "$OUT/${f}_riscv.s") 行"
  riscv64-unknown-elf-gcc -O0 -S "$OUT/${f}_free.c" -o "$OUT/${f}_riscv_gcc.s" 2>&1 | head -3
  [ -f "$OUT/${f}_riscv_gcc.s" ] && echo "  riscv64-unknown-elf-gcc OK: $(wc -l < "$OUT/${f}_riscv_gcc.s") 行"

  echo "--- 参考实现的输出 ---"
  case "$f" in
    fact) echo -n "  输入 5  ->  $(echo 5 | "$OUT/ref_$f")" ;;
    fib)  echo -n "  输入 6  ->  $(echo 6 | "$OUT/ref_$f" | tr '\n' ' ')" ;;
  esac
  echo
done
