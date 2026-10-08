# ============================================================================
# SysY 运行库（RISC-V rv64 参考实现 / "自实现运行库"兜底方案）
#
# 为什么需要它：
#   本机的 riscv64-unknown-elf-gcc 是 bare-metal 工具链，实测没有 sysroot、
#   没有 libc（`-print-sysroot` 为空，`-print-file-name=libc.a` 只回显 libc.a）。
#   因此课程提供的 libsysy_riscv.a 或这份自实现版本，是 B 线唯一可用的运行库。
#
# 它做了什么：
#   直接用 ecall 调用 Linux 用户态系统调用（qemu-riscv64 模拟的就是 Linux 用户态）：
#     write = 64, read = 63, exit = 93
#   并保证 _start 是弱符号：若课程库已提供 _start，则自动让位、不冲突。
#
# 编译（在本仓库根目录）：
#   riscv64-unknown-elf-gcc B-riscv/sylib_ref.S -c -o B-riscv/libsysy/sylib_ref.o -w
# ============================================================================

# 注意：这里刻意 *不写* .attribute arch。
#   本机 gcc 默认架构是 rv64imafdc_zicsr / ABI lp64d；
#   若手写 .attribute arch 写成不含 d 扩展的串（例如 "rv64i2p1_m2p0"），
#   GNU as 会直接报错：
#     Error: ilp32d/lp64d ABI can't be used when d extension isn't supported
#   实测：不带 .attribute 的 .s 用默认 arch/abi 汇编完全正常。
	.attribute	stack_align, 16
	.attribute	unaligned_access, 0
	.text

# ---------------------------------------------------------------------------
# main 的启动外壳：调用 main()，把返回值作为退出码交给 exit 系统调用
#
# ⚠️ 两个必须遵守的约束（都是实测踩出来的）：
#
#   1) _start 必须是全局强符号，并且链接时显式指定入口：
#          -Wl,-e,_start
#      原因：加上 -Ttext=0x90000000 之后，链接器的默认入口是"最低地址的符号"。
#      如果 main 恰好被放在 0x90000000，链接器就会把入口定成 main，_start 被整个
#      跳过，于是 main 返回后没有任何人执行 exit 系统调用 —— qemu 实测退出码
#      恒为 1（而不是 main 的返回值）。
#
#   2) 本段必须排在 .text 的最前面（_start 地址最低），双保险。
#      这就是下面这个 _start 段写在所有导出函数之前的原因。
# ---------------------------------------------------------------------------
	.text
	.globl	_start
	.type	_start, @function
_start:
	call	main
	li	a7, 93          # SYS_exit
	ecall
	j	.               # 不应到达

# ---------------------------------------------------------------------------
# 以下是 SysY 运行库函数本体（read/write 系统调用实现）
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# int getch(void) —— 读一个字符，返回 0..255（EOF 返回 -1）
# ---------------------------------------------------------------------------
	.globl	getch
getch:
	addi	sp, sp, -16
	sd	ra, 8(sp)
	sb	zero, 0(sp)     # 先把缓冲区清零，用于判断是否真的读到了字节
	li	a0, 0           # fd = 0 (stdin)
	mv	a1, sp          # buf
	li	a2, 1           # count = 1
	li	a7, 63          # SYS_read
	ecall
	li	t0, 1
	bne	a0, t0, .Lgetch_eof
	lbu	a0, 0(sp)
	j	.Lgetch_ret
.Lgetch_eof:
	li	a0, -1
.Lgetch_ret:
	ld	ra, 8(sp)
	addi	sp, sp, 16
	ret

# ---------------------------------------------------------------------------
# int getint(void) —— 跳过空白后解析一个可带负号的十进制整数
# 完全没有数字可读时返回 0，与 sylib 的行为一致
# ---------------------------------------------------------------------------
	.globl	getint
getint:
	addi	sp, sp, -32
	sd	ra, 24(sp)
	sw	zero, 16(sp)    # sign = 0 表示还没遇到 '-' 或数字
	sw	zero, 20(sp)    # value = 0
.Lgetint_loop:
	call	getch
	li	t0, -1
	beq	a0, t0, .Lgetint_end
	li	t0, 45          # '-'
	bne	a0, t0, .Lgetint_digit
	lw	t1, 16(sp)
	bnez	t1, .Lgetint_loop
	li	t1, 1
	sw	t1, 16(sp)      # sign = 1 表示接下来是负数
	j	.Lgetint_loop
.Lgetint_digit:
	li	t0, 48          # '0'
	blt	a0, t0, .Lgetint_space
	li	t0, 57          # '9'
	bgt	a0, t0, .Lgetint_space
	addi	a0, a0, -48
	lw	t1, 20(sp)
	li	t2, 10
	mul	t1, t1, t2
	add	t1, t1, a0
	sw	t1, 20(sp)
	lw	t1, 16(sp)
	ori	t1, t1, 2       # 标记"已经读到数字"
	sw	t1, 16(sp)
	j	.Lgetint_loop
.Lgetint_space:
	lw	t1, 16(sp)
	andi	t1, t1, 2
	beqz	t1, .Lgetint_loop   # 还没读到数字，继续跳过空白
.Lgetint_end:
	lw	a0, 20(sp)
	lw	t1, 16(sp)
	andi	t1, t1, 1
	beqz	t1, .Lgetint_ret
	negw	a0, a0
.Lgetint_ret:
	ld	ra, 24(sp)
	addi	sp, sp, 32
	ret

# ---------------------------------------------------------------------------
# void putch(int c) —— 输出一个字符
# ---------------------------------------------------------------------------
	.globl	putch
putch:
	addi	sp, sp, -16
	sd	ra, 8(sp)
	sb	a0, 0(sp)
	li	a0, 1           # fd = 1 (stdout)
	mv	a1, sp
	li	a2, 1
	li	a7, 64          # SYS_write
	ecall
	ld	ra, 8(sp)
	addi	sp, sp, 16
	ret

# ---------------------------------------------------------------------------
# void putint(int x) —— 输出十进制整数（含负号）
# ---------------------------------------------------------------------------
	.globl	putint
putint:
	addi	sp, sp, -32
	sd	ra, 24(sp)
	sw	a0, 16(sp)
	bgez	a0, .Lputint_abs
	li	a0, 45          # '-'
	call	putch
	lw	a0, 16(sp)
	negw	a0, a0
.Lputint_abs:
	sw	a0, 20(sp)
	addi	t0, sp, 16      # 从缓冲区尾部倒着填数字
	li	t1, 0           # 位数计数
	beqz	a0, .Lputint_zero
.Lputint_div:
	lw	t2, 20(sp)
	li	t3, 10
	remuw	t4, t2, t3
	addi	t4, t4, 48
	addi	t0, t0, -1
	sb	t4, 0(t0)
	divuw	t2, t2, t3
	sw	t2, 20(sp)
	addi	t1, t1, 1
	bnez	t2, .Lputint_div
	j	.Lputint_out
.Lputint_zero:
	addi	t0, t0, -1
	li	t4, 48          # '0'
	sb	t4, 0(t0)
	li	t1, 1
.Lputint_out:
	li	a0, 1
	mv	a1, t0
	mv	a2, t1
	li	a7, 64          # SYS_write
	ecall
	ld	ra, 24(sp)
	addi	sp, sp, 32
	ret
