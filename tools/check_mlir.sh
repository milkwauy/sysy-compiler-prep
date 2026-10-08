#!/bin/bash
# ============================================================================
# MLIR 进阶任务自检
#   用法（仓库根目录）：bash tools/check_mlir.sh
#
#   这个环境是 A、B 两人共用的，所以脚本对两边都能跑。
#   - mlir-opt / mlir-translate 没装时：只校验示例程序本身是不是合法的 MLIR 形状
#   - 装好之后：把 A 负责的 L1→L3 完整跑一遍，并检查交接物 l3.mlir 是否生成
#
#   产物写到仓库外面的 [B]sandbox/mlir，不污染 git 工作树。
#   需要留档进仓库的，自己把关键片段挑出来提交。
# ============================================================================
BASE="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$BASE" || exit 1
SRC=advanced-mlir/vecadd/vecadd.mlir
SAND="${SAND:-$(dirname "$BASE")/[B]sandbox}"
OUT="$SAND/mlir"
mkdir -p "$OUT"

echo "=== [1] 工具是否就绪 ==="
for t in mlir-opt mlir-translate; do
  if command -v $t >/dev/null; then
    printf "  %-16s %s\n" "$t" "$(command -v $t)"
  else
    printf "  %-16s 未安装\n" "$t"
  fi
done
if command -v mlir-opt >/dev/null; then
  echo "  版本: $(mlir-opt --version 2>&1 | head -1)"
else
  echo "  → 安装方法（需要你自己输密码）："
  echo "      sudo apt update && sudo apt install -y mlir-21-tools"
  echo "    或者用 Docker：docker run --rm -v \"\$PWD:/w\" -w /w \\"
  echo "      ghcr.io/llvm/llvm-project:main mlir-opt --version"
fi

echo
echo "=== [2] 从示例文件里抽出可解析的 MLIR 源 ==="
# 文件里 vecadd-parse-begin/end 之间的内容是真正的 MLIR 源，其余都是注释
# （sed 的范围会包含两行标记，所以用 // 开头的行过滤掉它们）
sed -n '/vecadd-parse-begin/,/vecadd-parse-end/p' "$SRC" \
  | grep -v '^\s*//' > "$OUT/vecadd_core.mlir"
echo "  抽出 $(wc -l < "$OUT/vecadd_core.mlir") 行，保存到 $OUT/vecadd_core.mlir"
echo "  内容："
sed 's/^/    /' "$OUT/vecadd_core.mlir"

echo
echo "=== [3] 用 mlir-opt 校验语法 ==="
if command -v mlir-opt >/dev/null; then
  if mlir-opt "$OUT/vecadd_core.mlir" -o /dev/null 2>"$OUT/parse.err"; then
    echo "  解析通过（示例程序是合法 MLIR）"
  else
    echo "  解析失败："; cat "$OUT/parse.err"
    echo "  → 可能是方言改名了，改用文件末尾的备用起点（memref + affine）"
  fi
else
  echo "  跳过（mlir-opt 未安装）"
fi

echo
echo "=== [4] A 负责的 L1 -> L2 -> L3 ==="
if ! command -v mlir-opt >/dev/null; then
  echo "  跳过（mlir-opt 未安装）"
  exit 0
fi
set -x
mlir-opt "$OUT/vecadd_core.mlir" \
  --pass-pipeline='builtin.module(func.func(linalg-generalize-named-ops))' \
  -o "$OUT/l1.mlir"
mlir-opt "$OUT/l1.mlir" --convert-linalg-to-loops -o "$OUT/l2.mlir"
mlir-opt "$OUT/l2.mlir" --convert-scf-to-cf     -o "$OUT/l3.mlir"
set +x

echo
echo "=== [5] 交接物检查（B 的输入）==="
for f in l1 l2 l3; do
  if [ -f "$OUT/$f.mlir" ]; then
    printf "  %-10s %s 行  %s\n" "$f.mlir" "$(wc -l < "$OUT/$f.mlir")" "$(grep -c 'linalg\|scf\|cf\.' "$OUT/$f.mlir") 处相关算子"
  else
    printf "  %-10s 未生成\n" "$f.mlir"
  fi
done

echo
echo "=== [6] 各层还剩哪些方言（观察"信息在哪一层消失"）==="
for f in "$OUT/vecadd_core.mlir" "$OUT/l1.mlir" "$OUT/l2.mlir" "$OUT/l3.mlir"; do
  [ -f "$f" ] || continue
  printf "  %-24s " "$(basename "$f")"
  grep -oE '\b(linalg|tensor|memref|scf|cf|arith|func|affine|llvm)\.[a-z_]+' "$f" \
    | cut -d. -f1 | sort -u | tr '\n' ' '
  echo
done

echo
echo "=== [7] B 负责的 L3.5 -> L4 -> L5 ==="
if [ -f "$OUT/l3.mlir" ]; then
  if mlir-opt "$OUT/l3.mlir" \
       --one-shot-bufferize='bufferize-function-boundaries' \
       --buffer-deallocation-pipeline \
       -o "$OUT/l3_5.mlir" 2>"$OUT/buf.err"; then
    echo "  L3.5 bufferization OK"
    mlir-opt "$OUT/l3_5.mlir" --convert-to-llvm -o "$OUT/l4.mlir" 2>&1 | head -5
    [ -f "$OUT/l4.mlir" ] && echo "  L4 convert-to-llvm OK"
    if command -v mlir-translate >/dev/null && [ -f "$OUT/l4.mlir" ]; then
      mlir-translate --mlir-to-llvmir "$OUT/l4.mlir" -o "$OUT/l5.ll" 2>&1 | head -5
      [ -f "$OUT/l5.ll" ] && echo "  L5 -> LLVM IR OK（可与第 2 章的 LLVM IR 对照）"
    fi
  else
    echo "  bufferization 失败（不同版本 pass 名可能不同）："; head -5 "$OUT/buf.err"
    echo "  → 备选写法，逐个试："
    echo "      --one-shot-bufferize"
    echo "      --empty-tensor-to-alloc-tensor --one-shot-bufferize"
    echo "      --bufferize --convert-bufferization-to-memref"
  fi
else
  echo "  跳过（没有 l3.mlir，先跑通上面第 4 步）"
fi
