#!/bin/bash
# ============================================================================
# 记录这台机器的工具链版本，用来和另外两台对齐
#   用法（WSL 里，仓库根目录）：bash tools/record_versions.sh
#   输出：<仓库外面>/[B]sandbox/versions_<主机名>.txt
#         （写在仓库外面，避免临时文件污染 git 工作树）
# ============================================================================
BASE="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$BASE" || exit 1
SAND="${SAND:-$(dirname "$BASE")/[B]sandbox}"
OUT="$SAND"
mkdir -p "$OUT"
F="$OUT/versions_$(hostname).txt"

first() { command -v "$1" >/dev/null 2>&1 && "$@" 2>&1 | head -1 || echo "未安装"; }

{
  echo "=============================================="
  echo "  工具链版本记录"
  echo "=============================================="
  echo "主机名      : $(hostname)"
  echo "用户        : $(whoami)"
  echo "记录时间    : $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo
  echo "--- 操作系统 ---"
  ( . /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" ) || echo "未知"
  echo "内核        : $(uname -r)"
  echo "架构        : $(uname -m)"
  echo
  echo "--- LLVM / clang 线（A 需要）---"
  printf "%-14s %s\n" clang      "$(first clang --version)"
  printf "%-14s %s\n" llc        "$(first llc --version)"
  printf "%-14s %s\n" opt        "$(first opt --version)"
  printf "%-14s %s\n" lli        "$(first lli --version)"
  printf "%-14s %s\n" llvm-as    "$(first llvm-as --version)"
  printf "%-14s %s\n" llvm-dis   "$(first llvm-dis --version)"
  echo
  echo "--- RISC-V 线（B 需要）---"
  printf "%-26s %s\n" riscv64-unknown-elf-gcc     "$(first riscv64-unknown-elf-gcc --version)"
  printf "%-26s %s\n" riscv64-unknown-elf-as      "$(first riscv64-unknown-elf-as --version)"
  printf "%-26s %s\n" riscv64-unknown-elf-objdump "$(first riscv64-unknown-elf-objdump --version)"
  printf "%-26s %s\n" qemu-riscv64                "$(first qemu-riscv64 --version)"
  echo
  echo "--- 进阶 MLIR（两人都要）---"
  printf "%-14s %s\n" mlir-opt       "$(first mlir-opt --version)"
  printf "%-14s %s\n" mlir-translate "$(first mlir-translate --version)"
  echo
  echo "--- 基础工具 ---"
  printf "%-14s %s\n" git    "$(first git --version)"
  printf "%-14s %s\n" make   "$(first make --version)"
  printf "%-14s %s\n" python3 "$(first python3 --version)"
  echo
  echo "--- RISC-V 工具链能力边界（B 必看）---"
  echo "sysroot  = '$(riscv64-unknown-elf-gcc -print-sysroot 2>/dev/null)'    （空 = 裸机，没有 libc）"
  echo "libc.a   = '$(riscv64-unknown-elf-gcc -print-file-name=libc.a 2>/dev/null)'"
  echo
  echo "--- Git 配置 ---"
  echo "user.name       = $(git config --global user.name 2>/dev/null || echo 未设置)"
  echo "user.email      = $(git config --global user.email 2>/dev/null || echo 未设置)"
  echo "core.autocrlf   = $(git config --global core.autocrlf 2>/dev/null || echo 未设置)"
  echo "core.quotepath  = $(git config --global core.quotepath 2>/dev/null || echo 未设置)"
  echo
  echo "--- 课程运行库是否就位 ---"
  for f in A-llvm/libsysy/libsysy_x86.a A-llvm/libsysy/sylib.so B-riscv/libsysy/libsysy_riscv.a; do
    [ -f "$f" ] && echo "有   $f" || echo "没有 $f"
  done
} | tee "$F"

echo
echo "已保存到：$F"
echo "把这一步的输出贴给对方，两边一对比就知道差在哪。"
