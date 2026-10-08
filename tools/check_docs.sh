#!/bin/bash
# 检查两份手册里引用的仓库文件是否真实存在（防止文档指向不存在的路径）
BASE="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$BASE" || exit 1

echo "=== 文档里提到的仓库文件是否存在 ==="
for f in .gitattributes .gitignore README.md 分工方案.md plan-A.md plan-B.md \
         管理员手册.md git与依赖安装指导.md 三机环境搭建清单.md \
         common/sysy_main.c common/sysy_main_ref.c common/env.md \
         common/examples/fact.c common/examples/fib.c \
         common/expected/case1.out common/expected/case2.out \
         common/testdata/case1.in common/testdata/case2.in \
         common/verify_expected.sh common/run_ref.sh \
         B-riscv/README.md B-riscv/sylib_ref.S \
         doc/report.md doc/pdf_text.txt \
         advanced-mlir/vecadd/vecadd.mlir \
         .github/workflows/verify.yml .github/pull_request_template.md \
         tools/check_examples.sh tools/check_laneA.sh tools/check_laneB.sh \
         tools/check_mlir.sh tools/check_docs.sh tools/record_versions.sh \
         tools/check_links.js tools/check_anchors.js; do
  if [ -e "$f" ]; then
    printf "  OK   %s\n" "$f"
  else
    printf "  缺失 %s   <-- 文档引用了不存在的文件！\n" "$f"
  fi
done

echo
echo "=== 文档之间的相互引用是否都能对上 ==="
grep -ohE '\]\(([A-Za-z0-9_./\u4e00-\u9fa5-]+\.(md|sh|c|S|mlir|yml|out|in))\)' \
  README.md 管理员手册.md git与依赖安装指导.md plan-A.md plan-B.md 分工方案.md 2>/dev/null \
  | sed 's/](//; s/)$//' | sort -u | while read -r link; do
    case "$link" in
      http*|"#") continue ;;
    esac
    if [ -e "$link" ]; then printf "  OK   %s\n" "$link"
    else printf "  缺失 %s   <-- 有文档链接指向不存在的文件\n" "$link"; fi
  done
