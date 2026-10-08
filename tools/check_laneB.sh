#!/bin/bash
# ============================================================================
# B 线自检：确认"RISC-V 汇编 + 交叉工具链 + qemu"这条流水线在本机可用
#   用法（在仓库根目录）：bash tools/check_laneB.sh
#   本机实测结论：libsysy_riscv.a 不存在，必须用 -nostdlib + 自实现运行库。
# ============================================================================
BASE="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$BASE" || exit 1
SAND="${SAND:-$(dirname "$BASE")/[B]sandbox}"
OUT="$SAND/laneB"
rm -rf "$OUT" && mkdir -p "$OUT"

# 已验证可用的链接参数（缺一不可，逐条原因见分工方案 §6）
LINK="riscv64-unknown-elf-gcc -nostdlib -static -mcmodel=medany \
      -Wl,--no-relax -Ttext=0x90000000 -Wl,-e,_start"

echo "=== [1] clang 是否带 RISC-V 后端 ==="
clang --print-targets 2>/dev/null | grep -i riscv || echo "!! 没有 riscv 目标"

echo
echo "=== [2] 交叉编译需要剥掉 libc 头文件 ==="
sed '/#include <stdio.h>/d' common/sysy_main.c > "$OUT/sysy_free.c"
echo "sysy_free.c: $(wc -l < "$OUT/sysy_free.c") 行"

echo
echo "=== [3] clang 交叉生成 RISC-V 汇编 ==="
if clang --target=riscv64-unknown-elf -O0 -S "$OUT/sysy_free.c" -o "$OUT/clang_O0.s" 2>"$OUT/clang.err"; then
  echo "clang -S OK: $(wc -l < "$OUT/clang_O0.s") 行"
else
  echo "!! clang 交叉生成失败："; head -5 "$OUT/clang.err"
fi

echo
echo "=== [4] 交叉生成 RISC-V 目标文件 + 反汇编 ==="
clang --target=riscv64-unknown-elf -O0 -c "$OUT/sysy_free.c" -o "$OUT/from_c.o" 2>&1 | head -3
if [ -f "$OUT/from_c.o" ]; then
  file "$OUT/from_c.o"
  riscv64-unknown-elf-objdump -d "$OUT/from_c.o" > "$OUT/from_c.dis"
  echo "--- main 前 8 行（注意 auipc + jalr 调用尚未定址）---"
  grep -A8 '<main>:' "$OUT/from_c.dis" | head -9
fi

echo
echo "=== [5] LLVM IR -> RISC-V 对象（必须先生成 riscv 版 IR）==="
clang --target=riscv64-unknown-elf -S -emit-llvm -O0 "$OUT/sysy_free.c" -o "$OUT/rv.ll" 2>&1 | head -3
grep -m1 "target triple" "$OUT/rv.ll" || true
llc -mtriple=riscv64-unknown-elf -filetype=obj "$OUT/rv.ll" -o "$OUT/from_ll.o" 2>&1 | head -3
[ -f "$OUT/from_ll.o" ] && file "$OUT/from_ll.o"

echo
echo "=== [6] gcc 交叉生成汇编（对照底本）==="
riscv64-unknown-elf-gcc -O0 -S "$OUT/sysy_free.c" -o "$OUT/gcc_O0.s" 2>"$OUT/gcc.err" \
  && echo "gcc -S OK: $(wc -l < "$OUT/gcc_O0.s") 行" || { echo "!! 失败"; head -5 "$OUT/gcc.err"; }

echo
echo "=== [7] 工具链能力边界（重要）==="
echo "sysroot = '$(riscv64-unknown-elf-gcc -print-sysroot)'   <- 空表示裸机，没有 libc"
echo "libc.a  = '$(riscv64-unknown-elf-gcc -print-file-name=libc.a)'   <- 找不到"
echo "qemu    = $(command -v qemu-riscv64 || echo '未安装')"

echo
echo "=== [8] 自实现运行库冒烟测试（getint/putint/putch）==="
if [ -f B-riscv/sylib_ref.S ]; then
  riscv64-unknown-elf-gcc B-riscv/sylib_ref.S -c -o "$OUT/sylib_ref.o" -w || exit 1
  cat > "$OUT/io.S" <<'EOF'
	.text
	.globl	main
main:
	addi	sp, sp, -16
	sd	ra, 8(sp)
	call	getint
	mv	s0, a0
	call	getint
	add	a0, s0, a0
	call	putint
	li	a0, 10
	call	putch
	ld	ra, 8(sp)
	addi	sp, sp, 16
	li	a0, 0
	ret
EOF
  riscv64-unknown-elf-gcc "$OUT/io.S" -c -o "$OUT/io.o" -w
  $LINK "$OUT/sylib_ref.o" "$OUT/io.o" -o "$OUT/io" 2>&1 | head -3
  echo "入口 = $(riscv64-unknown-elf-readelf -h "$OUT/io" | awk '/Entry point/{print $4}')"
  for pair in "6 4|10" "12 30|42" "-9 25|16"; do
    inp="${pair%%|*}"; exp="${pair##*|}"
    got=$(printf '%s\n' "$inp" | qemu-riscv64 "$OUT/io" 2>&1)
    [ "$got" = "$exp" ] && echo "  getint/putint [$inp] -> [$got] PASS" \
                        || echo "  getint/putint [$inp] -> [$got] 期望 [$exp] FAIL"
  done
else
  echo "未找到 B-riscv/sylib_ref.S"
fi

echo
echo "=== [9] 手写 main.S 的完整验证（需要 B-riscv/main.S）==="
if [ -f B-riscv/main.S ]; then
  riscv64-unknown-elf-gcc B-riscv/main.S -c -o "$OUT/main.o" -w
  riscv64-unknown-elf-readelf -r "$OUT/main.o" > "$OUT/reloc.txt" 2>&1
  echo "重定位项数: $(grep -c 'R_RISCV' "$OUT/reloc.txt")"
  riscv64-unknown-elf-nm "$OUT/main.o" > "$OUT/nm_obj.txt"
  echo "未定义符号(U): $(grep -c ' U ' "$OUT/nm_obj.txt")"
  $LINK "$OUT/sylib_ref.o" "$OUT/main.o" -o "$OUT/main" 2>&1 | head -3
  if [ -f "$OUT/main" ]; then
    riscv64-unknown-elf-objdump -d "$OUT/main" > "$OUT/anti_exe.S"
    for c in case1 case2; do
      if qemu-riscv64 "$OUT/main" < "common/testdata/$c.in" | diff -q - "common/expected/$c.out" >/dev/null; then
        echo "$c PASS"
      else
        echo "$c FAIL"; qemu-riscv64 "$OUT/main" < "common/testdata/$c.in" | diff - "common/expected/$c.out"
      fi
    done
  else
    echo "!! 链接失败"
  fi
else
  echo "尚未编写 B-riscv/main.S，跳过（这正是 B 的核心任务）"
fi
