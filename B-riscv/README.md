# B 线：RISC-V（rv64）汇编编程

> 负责人：**B**。本目录只有 B 有写权限，A 不碰。

## 本目录的文件

| 文件 | 说明 |
|---|---|
| `main.S` | **B 的核心交付物**：手写的、与 `common/sysy_main.c` 等价的 RISC-V 汇编（待编写） |
| `sylib_ref.S` | **自实现 SysY 运行库**（`getch/getint/putch/putint` + `_start`）。本机已实测通过 |
| `ref/` | `clang --target=riscv64-unknown-elf -S` 与 `riscv64-unknown-elf-gcc -S` 生成的参考汇编（对照底本，gitignore） |
| `obj/` | 目标文件、反汇编、符号表、重定位表（gitignore） |
| `libsysy/` | 课程提供的 `libsysy_riscv.a`（若已拿到，放这里，gitignore） |

## 为什么需要 `sylib_ref.S`

本机的 `riscv64-unknown-elf-gcc` 是 **bare-metal 工具链**：实测 `-print-sysroot` 为空，
没有 `libc.a`、没有 `crt0.o`、没有 `libgloss.a`。因此 **实验指导里那条链接命令按原样会失败**：

```
ld: cannot find crt0.o: No such file or directory
ld: cannot find -lc: No such file or directory
ld: cannot find -lgloss: No such file or directory
```

两条正路：
1. 拿到课程飞书群的 `libsysy_riscv.a`（推荐，和实验指导一致）；
2. 用本目录的 `sylib_ref.S` —— 直接 `ecall` 调 Linux 用户态系统调用
   （`write`=64、`read`=63、`exit`=93），不依赖任何 libc。**已实测 5 组输入输出全部 PASS。**

## 实测通过的编译与运行命令

```bash
# 1. 汇编运行库与用户程序
riscv64-unknown-elf-gcc B-riscv/sylib_ref.S -c -o B-riscv/obj/sylib_ref.o -w
riscv64-unknown-elf-gcc B-riscv/main.S      -c -o B-riscv/obj/main.o      -w

# 2. 链接（七个参数缺一不可，原因见下表）
riscv64-unknown-elf-gcc -nostdlib -static -mcmodel=medany \
    -Wl,--no-relax,-Ttext=0x90000000 -Wl,-e,_start \
    B-riscv/obj/sylib_ref.o B-riscv/obj/main.o -o B-riscv/obj/main

# 3. 运行验证
qemu-riscv64 ./B-riscv/obj/main < common/testdata/case1.in | diff - common/expected/case1.out

# 4. 汇编器/链接器做了什么
riscv64-unknown-elf-readelf -r B-riscv/obj/main.o > B-riscv/obj/reloc.txt
riscv64-unknown-elf-nm B-riscv/obj/main.o > B-riscv/obj/nm_obj.txt
riscv64-unknown-elf-objdump -d B-riscv/obj/main.o > B-riscv/obj/anti_obj.S
riscv64-unknown-elf-objdump -d B-riscv/obj/main   > B-riscv/obj/anti_exe.S
```

一键自检：`bash tools/check_laneB.sh`

## 三条必须知道的坑（报告里可以直接写成"汇编器/链接器行为分析"）

| 坑 | 现象 | 原因与修法 |
|---|---|---|
| **入口点被链接器换掉** | 汇编、链接都成功，qemu 退出码却恒为 **1** 且无输出 | 加 `-Ttext=0x90000000` 后，链接器默认入口取"**最低地址的符号**"。若 `main` 落在 0x90000000，入口就变成 `main`，`_start` 被整个跳过，没人执行 `exit` 系统调用。修法：`-Wl,-e,_start` + 运行库目标文件排在用户目标文件**之前** |
| **`.attribute arch` 与 ABI 冲突** | `Error: ilp32d/lp64d ABI can't be used when d extension isn't supported` | 手写 `.attribute arch, "rv64i2p1_m2p0"`（不含 `d` 扩展）与本机默认 ABI `lp64d` 矛盾，GNU as 直接拒绝。修法：**别写 `.attribute arch`**，用默认 arch/abi |
| **ABI 混用** | `can't link double-float modules with soft-float modules` | clang 交叉目标默认 `rv64imac` + `lp64d`（不自洽），llc 默认是软浮点。修法：统一 `-march=rv64gc -mabi=lp64d` |

## 交叉编译 C 源程序时的额外注意

`#include <stdio.h>` 在交叉目标下必然失败（bare-metal 没有 stdio.h）：

```bash
sed '/#include <stdio.h>/d' common/sysy_main.c > B-riscv/ref/sysy_free.c
clang --target=riscv64-unknown-elf -march=rv64gc -mabi=lp64d -O0 -S \
      B-riscv/ref/sysy_free.c -o B-riscv/ref/clang_O0.S
```

另外：**要生成 RISC-V 的 LLVM IR，必须在 clang 那一步就带 `--target=riscv64-unknown-elf`**。
先生成 x86 版 IR 再交给 `llc -mtriple=riscv64-unknown-elf` 会报
`'x86-64' is not a recognized processor for this target`（IR 里的 datalayout 已经写死成 x86）。

## 关于"借鉴 clang 生成的汇编"的说明

`B-riscv/ref/clang_O0.S` 是**同一份源程序**由编译器生成的汇编，作为抄写与对照的底本。
最终 `main.S` 必须是 B 自己逐条理解后写出来的，并在报告中说明哪些部分参考了编译器输出 ——
报告的 3.7 节正是要对比"手写版与编译器生成版"的差异，这一节本身就是分数。
