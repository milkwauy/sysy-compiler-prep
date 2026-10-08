# B 的工作方案（RISC-V 汇编这条线）

> 这份只管 B 自己干什么，你自己看完就能开工，不需要和 A 商量。
> A 的方案在 `plan-A.md` 里，你不用去看。

---

## 一、你负责什么

题目一共四块内容，你负责后两块：

3. **熟悉汇编语言**——自己写一份 RISC-V 汇编（`.S` 文件），和源程序等价，能跑出一样的结果。
4. **观察 AI 编译器 MLIR 中端处理过程**（进阶 1 分）——看 VecAdd 示例逐层降低的过程。

A 负责前两块（编译过程、LLVM IR）。**你一个字都不用写 LLVM IR**（除非你想自己练一遍，那也随你）。

> 题目说"只做 RISC-V，不做 ARM"，所以 ARM 那条线整个跳过，不用看。

你干活的地方固定是这几个目录：

```
B-riscv/        你自己的工作目录，A 不会动
                （里面有我写好并实测通过的自实现运行库 sylib_ref.S）
doc/report.md   你只写第 3 章和第 4 章，以及第 5 章结论里标了 "by B" 的那一段
tools/          自检脚本，只读
```

---

## 二、你要交的东西

| 交付物 | 放在哪 | 验收标准 |
|---|---|---|
| 手写的 RISC-V 汇编程序 | `B-riscv/main.S` | 链接运行库后在 `qemu-riscv64` 上跑，两个测试用例都和期望输出逐字节一样 |
| 参考汇编底本 | `B-riscv/ref/` | clang 和 gcc 交叉生成的 `.S`，用来对照抄写和写差异分析 |
| 汇编器/链接器分析 | `B-riscv/obj/` | 重定位表、符号表、`.o` 与可执行文件的反汇编对照 |
| 一键复现脚本 | `B-riscv/build.sh` | 换台机器跑一遍也能出同样结果 |
| 报告第 3、4 章 | `doc/report.md` | 用自己跑出来的产物说话，不要抄指导书 |
| 原始笔记 | `B-riscv/B_notes.md` | 随手记，不用写好看，是写报告的素材 |

期望输出我这边已经实测冻结好了，在 `common/expected/case1.out` 和 `case2.out`。你可以随时自己验一遍：

```bash
bash common/verify_expected.sh      # 应该打印 case1 PASS / case2 PASS
```

**先跑这个，确认你的 qemu 和汇编器是通的：**

```bash
bash tools/check_laneB.sh
```

它会一步步检查交叉编译、反汇编、自实现运行库，最后打印三行
`getint/putint [6 4] -> [10] PASS` 之类的结果。**这个脚本的最后一步会跳过**，
因为 `B-riscv/main.S` 还没写 —— 那个文件正是你的主要任务。

---

## 三、开工前，先自己独立做这三件小事

**这三件事 A 也会自己做一遍，你们各做各的，不需要对答案。**
做完你就知道指导书里那两段示例程序编译成 RISC-V 汇编长什么样了。

三个程序已经放在仓库里，不用自己敲：

```
common/examples/fact.c        阶乘（指导书 1.3 节的"阶乘"示例）
common/examples/fib.c         斐波那契数列（指导书 1.3 节的第二个示例）
common/sysy_main.c            你们俩的主要测试程序（覆盖的语言特性最多）
```

### 小事 1：把阶乘和斐波那契交叉编译成 RISC-V 汇编

```bash
mkdir -p B-riscv/ref

# 交叉目标下没有 stdio.h（裸机工具链没有 libc），先把那行 include 删掉
for f in fact fib sysy_main; do
  sed '/#include <stdio.h>/d' common/examples/$f.c > B-riscv/ref/${f}_free.c 2>/dev/null \
    || sed '/#include <stdio.h>/d' common/$f.c > B-riscv/ref/${f}_free.c
done

# 用 clang 生成一份，用 gcc 再生成一份，两份对照着看
clang --target=riscv64-unknown-elf -O0 -S B-riscv/ref/fact_free.c -o B-riscv/ref/fact_clang_O0.S
riscv64-unknown-elf-gcc          -O0 -S B-riscv/ref/fact_free.c -o B-riscv/ref/fact_gcc_O0.S

clang --target=riscv64-unknown-elf -O0 -S B-riscv/ref/fib_free.c -o B-riscv/ref/fib_clang_O0.S
riscv64-unknown-elf-gcc          -O0 -S B-riscv/ref/fib_free.c -o B-riscv/ref/fib_gcc_O0.S
```

看的时候留意这几件事（都是报告里的素材）：

- 阶乘里那个 `while (i <= n)` 循环，汇编里是几条指令？比较用哪条（`bge`？`blt`？），跳转标签怎么命名？
- 乘法和取余分别变成了哪条指令？（`mulw`？`remw`？——这属于 M 扩展）
- 斐波那契里 `t = b; b = a + b; a = t;` 这段，编译器有没有真的用栈上那个临时变量？
  还是直接在寄存器之间倒腾？
- 两个程序里函数开头的 `addi sp, sp, -N` 和结尾的 `addi sp, sp, N` 是不是配对的？N 为什么总是 16 的倍数？

（参考：实测交叉编译出来的汇编行数是 —— 阶乘 clang 55 行 / gcc 52 行，斐波那契 clang 68 行 / gcc 67 行。
你会看到 clang 和 gcc 生成的风格不太一样，这个差异本身就值得在报告里写一段。）

### 小事 2：手动看一份指导书的示例汇编

指导书 4.2 节给了一段 `max` 函数的 RISC-V 汇编（原文是从 `riscv64-unknown-elf-gcc -O2`
生成的）。**别背，也别直接抄**，用你自己生成的 `.S` 对照着看，找出区别。

指导书里提到的那几个点你要真看懂（报告 3.1 节要写）：

- 参数为什么在 `a0`、`a1` 里？返回值为什么放 `a0`？（RISC-V 调用约定）
- `ret` 这条指令实际展开是什么？（`jalr x0, 0(ra)`）
- `sext.w a0, a5` 是在干什么？为什么 32 位的结果要符号扩展到 64 位？
- `lla` 和 `la` 有什么区别？（伪指令，展开成什么，跟内存模型有什么关系）

### 小事 3：交叉编译出 `.o`，看反汇编、符号表、重定位

```bash
mkdir -p B-riscv/obj
clang --target=riscv64-unknown-elf -O0 -c B-riscv/ref/fact_free.c -o B-riscv/obj/fact.o

file B-riscv/obj/fact.o                                        # 确认是 UCB RISC-V
riscv64-unknown-elf-objdump -d B-riscv/obj/fact.o > B-riscv/obj/fact.dis
riscv64-unknown-elf-nm     B-riscv/obj/fact.o > B-riscv/obj/fact.nm
riscv64-unknown-elf-readelf -r B-riscv/obj/fact.o > B-riscv/obj/fact.reloc

head -30 B-riscv/obj/fact.dis
cat B-riscv/obj/fact.reloc
```

看的时候留意：

- `.o` 里 `getint`、`putint` 这些函数的地址是什么？（应该是 0 或者很小——因为它们还没被链接）
- `nm` 输出里这些符号前面的字母是什么？（`U` = undefined，未定义，等着链接器来填）
- `readelf -r` 列出的重定位项是什么类型？（应该能看到 `R_RISCV_CALL_PLT` 之类）
- **调用处的 `auipc` + `jalr` 两条指令，为什么这样就能算出目标地址？**

> 这三件小事大概 1.5 小时。做完你就有了写报告第 3 章的绝大部分素材。
> 中间任何一步报错，先重新跑一遍 `bash tools/check_laneB.sh` 看是哪一环断了。

---

## 四、你的主线任务（按顺序做，每步都能独立验证）

### 第 1 步：把主程序的交叉编译产物做齐

```bash
sed '/#include <stdio.h>/d' common/sysy_main.c > B-riscv/ref/sysy_free.c

clang --target=riscv64-unknown-elf -O0 -S B-riscv/ref/sysy_free.c -o B-riscv/ref/clang_O0.S
clang --target=riscv64-unknown-elf -O2 -S B-riscv/ref/sysy_free.c -o B-riscv/ref/clang_O2.S
riscv64-unknown-elf-gcc          -O0 -S B-riscv/ref/sysy_free.c -o B-riscv/ref/gcc_O0.S
riscv64-unknown-elf-gcc          -O2 -S B-riscv/ref/sysy_free.c -o B-riscv/ref/gcc_O2.S

wc -l B-riscv/ref/*.S      # 实测：clang -O0 是 534 行，gcc -O0 是 520 行
```

拿 `clang_O0.S` 当你写 `main.S` 的**底本**。允许看、允许对照，但要求是你自己一行一行理解后写出来的，
报告里要说明哪些部分参考了编译器输出。**这个"手写版和编译器生成版的差异对比"本身就是报告 3.7 节的分数。**

### 第 2 步：手写 `B-riscv/main.S`

这是你这份工作里**最花时间、也最值钱**的一步。要求：

- 不许让编译器生成，**自己一行一行写**；
- 每个函数开头 `.globl 函数名`，函数体自己管栈帧（`addi sp, sp, -N` / `addi sp, sp, N` 配对，N 是 16 的倍数）；
- 必须覆盖：`while` 循环、`for` 嵌套循环、`if/else`、`break`、`continue`、递归调用、
  全局变量、全局常量、全局二维数组、浮点运算、取模；
- 调 `getint` / `putint` / `putch` 时按调用约定把参数放 `a0`~`a7`；
- 自己算二维数组的下标：`mat[i][j]` 的地址 = `mat + (i*3 + j)*4`。

几个具体的写法提示：

```asm
# 函数框架（叶子函数不调别人时，可以不存 ra）
	.text
	.globl	gcd
gcd:
	addi	sp, sp, -16
	sd	ra, 8(sp)          # 调了别的函数才需要存 ra
	...
	ld	ra, 8(sp)
	addi	sp, sp, 16
	ret

# 循环比较：while (b != 0)
.Lloop:
	beqz	a1, .Lend          # b == 0 就跳出
	remw	t0, a0, a1         # t = a % b   （M 扩展）
	mv	a0, a1
	mv	a1, t0
	j	.Lloop
.Lend:
```

写完自检语法：

```bash
riscv64-unknown-elf-gcc B-riscv/main.S -c -o B-riscv/obj/main.o -w
riscv64-unknown-elf-objdump -d B-riscv/obj/main.o | head -40
```

### 第 3 步：链接并跑起来（这一步有三个坑，我都替你踩过了）

我们已经确认：**你机器上没有任何 SysY 运行库**，而且 `riscv64-unknown-elf-gcc` 是裸机工具链，
没有 `crt0.o`、没有 `libc.a`。所以**指导书 4.3 节那条链接命令按原样会失败**，报错是
`cannot find crt0.o` / `cannot find -lc` / `cannot find -lgloss`。

我已经写好运行库并实测通过了：**`B-riscv/sylib_ref.S`**。它直接用 `ecall` 调 Linux 系统调用
（`write`=64、`read`=63、`exit`=93），实现了 `getch`、`getint`、`putch`、`putint` 和 `_start`。
5 组输入输出实测全部正确。你要理解它、在报告里讲清它，但不用重写。

**实测通过的链接命令（七个参数缺一不可）：**

```bash
riscv64-unknown-elf-gcc B-riscv/sylib_ref.S -c -o B-riscv/obj/sylib_ref.o -w
riscv64-unknown-elf-gcc B-riscv/main.S      -c -o B-riscv/obj/main.o      -w

riscv64-unknown-elf-gcc -nostdlib -static -mcmodel=medany \
    -Wl,--no-relax,-Ttext=0x90000000 -Wl,-e,_start \
    B-riscv/obj/sylib_ref.o B-riscv/obj/main.o -o B-riscv/obj/main

qemu-riscv64 ./B-riscv/obj/main < common/testdata/case1.in | diff - common/expected/case1.out
```

**三个坑（都是我实际调试出来的，报告里写出来很有价值）：**

| 坑 | 现象 | 原因 |
|---|---|---|
| **入口点被链接器换掉** | 汇编、链接都成功，qemu 退出码却恒为 **1**，什么都不输出 | 加了 `-Ttext=0x90000000` 之后，链接器的默认入口是"**最低地址的那个符号**"。如果 `main` 落在 0x90000000，入口就变成 `main`，`_start` 被整个跳过，于是没人执行 `exit` 系统调用。**修法：`-Wl,-e,_start` 显式指定入口，并且运行库目标文件排在 `main.o` 前面** |
| **`.attribute arch` 与 ABI 冲突** | `Error: ilp32d/lp64d ABI can't be used when d extension isn't supported` | 手写 `.attribute arch, "rv64i2p1_m2p0"`（不含 `d` 扩展）和本机默认 ABI `lp64d` 矛盾，GNU as 直接拒绝。**修法：别写 `.attribute arch`**，用默认的 |
| **ABI 混用** | `can't link double-float modules with soft-float modules` | clang 交叉目标默认 `rv64imac`+`lp64d`（这俩本身就不自洽），llc 默认是软浮点。**修法：统一用 `-march=rv64gc -mabi=lp64d`** |

两个测试用例都要过：

```bash
for c in case1 case2; do
  qemu-riscv64 ./B-riscv/obj/main < common/testdata/$c.in | diff - common/expected/$c.out \
    && echo "$c PASS"
done
```

如果拿到了课程提供的 `libsysy_riscv.a`，那就换一条路再验一次（两条路都跑通更有说服力）：

```bash
riscv64-unknown-elf-gcc -nostdlib -static -mcmodel=medany \
    -Wl,--no-relax,-Ttext=0x90000000 -Wl,-e,_start \
    B-riscv/libsysy/libsysy_riscv.a B-riscv/obj/main.o -o B-riscv/obj/main_libsy
```

> 注意：课程那个库如果不是同一套 ABI，可能链接不上（报上面第三个坑那个错）。
> 真接不上就说明原因，用自实现运行库交差，报告里写清楚，这不算扣分点。

### 第 4 步：把"汇编器做了什么"和"链接器做了什么"说清楚

这一步是为了报告 3.3、3.4 节。命令都很短：

```bash
# 可重定位目标文件里有什么
riscv64-unknown-elf-readelf -h -S B-riscv/obj/main.o > B-riscv/obj/sections_obj.txt
riscv64-unknown-elf-readelf -r    B-riscv/obj/main.o > B-riscv/obj/reloc_obj.txt
riscv64-unknown-elf-nm            B-riscv/obj/main.o > B-riscv/obj/nm_obj.txt
riscv64-unknown-elf-objdump -d    B-riscv/obj/main.o > B-riscv/obj/anti_obj.S

# 链接之后又变成什么样
riscv64-unknown-elf-readelf -h -S B-riscv/obj/main   > B-riscv/obj/sections_exe.txt
riscv64-unknown-elf-nm            B-riscv/obj/main   > B-riscv/obj/nm_exe.txt
riscv64-unknown-elf-objdump -d    B-riscv/obj/main   > B-riscv/obj/anti_exe.S

# 重点：同一个函数在两边长什么样
grep -A12 '<main>:' B-riscv/obj/anti_obj.S     # 地址是 0 或很小，调用处是占位
grep -A12 '<main>:' B-riscv/obj/anti_exe.S     # 地址被填实，auipc+jalr 已经定址
```

**报告要能回答这几个问题**：

- `.o` 里 `main` 的地址为什么是 0 附近？（还没分配最终地址）
- `nm` 里 `U` 标记的符号是什么？谁负责填上它？
- 重定位项 `R_RISCV_CALL_PLT` 是在修哪两条指令？
- 为什么 `.o` 不能直接运行？（地址没定、外部符号没解析）
- `-Wl,--no-relax` 关掉了什么？（链接器的松弛优化：把 `auipc+jalr` 缩成 `jal` 之类，开了之后汇编和最终指令不是一一对应，不好对照分析）
- `-mcmodel=medany` 为什么必须加？（不加会报 `relocation truncated to fit: R_RISCV_HI20`；这正是指导书 4.2 节讲的寻址方式问题）

### 第 5 步：写 `B-riscv/build.sh`

把上面所有命令按顺序写进一个脚本，加上 `set -e`，让任何人跑一遍就能重新生成全部产物。

### 第 6 步：写报告第 3 章

直接改 `doc/report.md`，**只填第 3 章，和第 5 章里 `<!-- by B -->` 那一段**。
小节的标题和编号已经定好了，**不要改标题**（A 也在同一个文件里写，改标题会撞车）。

---

## 五、报告怎么写才不像抄的

指导书 4.2 节已经给了一段 RISC-V 汇编并逐行解释了。你再抄一遍没有分。
能拿分的是**你自己测出来的东西**和**你自己踩到的坑**。建议每节按这个套路写：

> 我写了什么 → 汇编器/链接器怎么处理它 → 得到什么结果 → 和我的预期有没有不一样

几个现成的、别人大概率写不出来的点：

1. **那三个链接坑**——尤其是"入口点被链接器换掉，qemu 退出码恒为 1"这一条。
   从现象到原因到修法完整讲一遍，比背十条指令有说服力得多。这直接就是 3.4 节"链接器做了什么"。
2. **自实现运行库**：用 `ecall` 调 `write/read/exit` 系统调用。把
   "为什么裸机工具链下必须自己写"和"RISC-V 的系统调用怎么传参（a7 放调用号，a0-a2 放参数）"讲清楚。
3. **`-Wl,--no-relax` 的作用**：拿开关前后的反汇编对比一下，说明链接器除了填地址还会改指令。
4. **`-mcmodel=medany`**：指导书 4.2 节讲了 `lui+addi` / `auipc+addi` / `la` / `lla` 的区别，
   你实际踩一次 `R_RISCV_HI20` 截断错误，再讲为什么 `-Ttext=0x90000000` 就必须配 `medany`，
   这条线就完全串起来了。
5. **手写版 vs 编译器生成版**（3.7 节）：指令条数、用的寄存器个数、栈帧大小、
   有没有内联、`-O0` 和 `-O2` 差多少。列个表就行，表本身就是结论。

写得像"我写了一段汇编并把它跑通了"，而不是"我读了一本书"。

---

## 六、MLIR 进阶（1 分）：你和 A 一人跑一半

这块改成**两人协作**：把 lowering 链从中间切开，**A 负责上半段（L1→L3）**，你负责下半段（L3→L5）。
切点是 `l3.mlir`。这样你俩各自都有真东西可写，但**依然不用一起坐在电脑前**。

### 你的输入：A 交给你的 `l3.mlir`

A 会跑完这三层并把结果放在 `advanced-mlir/logs/l3.mlir`：

| 层 | 谁跑 | 命令 | 这一层发生了什么 |
|---|---|---|---|
| L1 | A | `linalg-generalize-named-ops` | `linalg.add` 泛化成 `linalg.generic` |
| L2 | A | `convert-linalg-to-loops` | 降成显式循环，"张量"概念开始消失 |
| L3 | A | `convert-scf-to-cf` | 结构化控制流降成基本块 + 条件跳转 |
| **L3.5** | **你** | `one-shot-bufferize` | **张量变成内存缓冲**，见下方说明 |
| L4 | **你** | `convert-to-llvm` | 全部降到 LLVM 方言 |
| L5 | **你** | `mlir-translate` | 变成 LLVM IR 文本，与 A 的第 2 章汇合 |

**你不需要自己跑 L1→L3**，直接等 A 的 `l3.mlir`。如果 A 还没跑出来，你可以先跑个最低限度的自检
确认环境是通的：

```bash
bash tools/check_mlir.sh      # 工具没装它会告诉你怎么装
```

### 你负责的三步

```bash
# L3.5：张量要变成内存。tensor 是值语义（没有地址），memref 是内存语义（有地址）。
#       这一步必须先做 bufferization，否则下一步 --convert-to-llvm 会因为
#       tensor 没法转成内存而直接报错。
mlir-opt advanced-mlir/logs/l3.mlir \
    --one-shot-bufferize='bufferize-function-boundaries' \
    --buffer-deallocation-pipeline \
    -o advanced-mlir/logs/l3_5.mlir

# L4：全部降到 LLVM 方言
mlir-opt advanced-mlir/logs/l3_5.mlir --convert-to-llvm -o advanced-mlir/logs/l4.mlir

# L5：LLVM 方言 -> LLVM IR 文本
mlir-translate --mlir-to-llvmir advanced-mlir/logs/l4.mlir -o advanced-mlir/logs/l5.ll
```

> **`--convert-to-llvm` 报错怎么排查**：如果它抱怨还有 `tensor` 类型或者某个方言没降完，
> 说明 bufferization 没做干净。按顺序试这几个写法（不同版本名字不一样）：
> ```bash
> mlir-opt l3.mlir --one-shot-bufferize -o t.mlir
> mlir-opt l3.mlir --empty-tensor-to-alloc-tensor --one-shot-bufferize -o t.mlir
> mlir-opt l3.mlir --convert-bufferization-to-memref -o t.mlir
> mlir-opt --help | grep -i bufferize        # 看你这版到底叫什么
> ```
> 最后一条最有用——**直接问你这个版本有哪些 pass，比猜名字快得多**。

### 你这一半最值得写进报告的三件事

1. **bufferization 是"值语义 → 内存语义"的跨越**。前面几层都在讲"算什么"，
   到这一步才第一次决定"算的结果放在哪块内存里"。这是 MLIR 分层设计最核心的一点，
   也是它和 LLVM IR 最大的不同——**LLVM IR 里压根没有 tensor 这种东西，一上来就是指针和内存**。
2. **L5 的 `.ll` 和 A 手写的 `main.ll` 是同一个层次的东西**。
   拿两份对着看：MLIR 走到头长出来的 LLVM IR，和人类直接手写的 LLVM IR，
   结构上像不像？像在哪、不像在哪？**这一对比就是第 4 章最有分量的一段**。
3. **方言清单的变化**（A 也会打这张表，你补上 L3.5→L5 的后半段）：

```bash
for f in l3 l3_5 l4; do
  printf "%-10s " "$f"
  grep -oE '\b(linalg|tensor|memref|scf|cf|arith|func|affine|llvm)\.[a-z_]+' \
    advanced-mlir/logs/$f.mlir | cut -d. -f1 | sort -u | tr '\n' ' '
  echo
done
```

你会看到 `tensor` 在 L3.5 消失、`memref` 出现，到 L4 又大部分变成 `llvm.` 开头的算子。
**"信息在哪一层丢掉、在哪一层冒出来"用这张表说最清楚。**

### 每层要回答的三个问题（报告第 4 章的固定格式）

1. 这一层还能看见"两个向量相加"这个意思吗？
2. 这一层新出现了什么概念？（循环？下标？指针？基本块？）
3. 上一层的哪些信息在这一层永久丢掉了？

### 你写在报告的哪一节

报告 `doc/report.md` 第 4 章已经按 `4.1 / 4.2 / 4.3 / 4.4` 分好了：

- **4.1**（MLIR 多级方言与 LLVM IR 单层的本质区别）—— A 写，你别动
- **4.2**（L1→L3 逐层观察）—— A 写
- **4.3**（L3→L5、bufferization、与 LLVM IR 汇合）—— **你写**
- **4.4**（结论）—— 你写 `<!-- by B -->` 那段，A 写 `<!-- by A -->` 那段

### 环境

**你机器上现在没有 `mlir-opt` / `mlir-translate`。** 要你自己在 WSL 里装（要输密码，我装不了）：

```bash
sudo apt update && sudo apt install -y mlir-21-tools
```

> **只装一次，你和 A 共用 WSL 里这一份**，不要各装一遍——这也是"共用环境"该省的地方。
> 你装的是 MLIR 21，而课程 PPT 里提到 Ascend NPU IR 基于 LLVM 15 时代的 MLIR。
> **pass 名字在不同版本之间确实改过**。报 "unknown pass" 就用
> `mlir-opt --help | grep -i <关键词>` 找当版本的名字，报告里如实记一句版本差异即可。
>
> 实在装不上，就跳过这 1 分，**别为它耽误基础 4 分**。

---

## 七、和 A 的界线（照这个执行就不会吵架）

| 情况 | 怎么办 |
|---|---|
| 你发现 `common/` 里的源程序有问题 | **不要直接改**。在 GitHub 开一个 Issue 写上"哪里不对、建议怎么改"。因为 A 也依赖这份文件，你改了会让他白跑一遍 |
| 你想改 `common/examples/fact.c` 之类 | 同上。要么开 Issue，要么**复制一份到你自己的 `B-riscv/ref/` 目录下改**，别动公共文件 |
| 你看不懂 A 的 `.ll` 文件 | 不用看。你不需要理解 LLVM IR |
| A 的进度慢 | 照常提交你自己那半。报告里如实写分工比例就行，不要停下来等 |
| 你需要 A 配合 | 先去 GitHub 开 Issue。能异步说清的事不要当面说 |
| 报告格式不统一 | 已经定好了：你只用 `doc/figures/fig-B-*.png` 和"表 B-1"这种编号，A 用 `A-`。物理上不可能撞 |

**唯一必须和 A 打照面的时刻**，是开工前确认三件事（15 分钟，说清楚就散）：
①`common/` 里的三个程序都不再改；②期望输出用 `common/expected/` 里那两个文件；
③报告骨架的标题编号不动。确认完就各干各的。

---

## 八、自查清单（做完一条打个勾，不用等 A 确认）

- [ ] 阶乘、斐波那契各自生成了 clang 版和 gcc 版的 RISC-V 汇编，放在 `B-riscv/ref/`
- [ ] 能说出阶乘的 `while` 循环在汇编里对应哪些指令和标签
- [ ] 能说出乘法和取余分别是哪条指令（M 扩展）
- [ ] `fact.o` 的反汇编、符号表、重定位表都看过，能解释 `U` 标记和重定位项
- [ ] `bash tools/check_laneB.sh` 全绿（除了最后一步要等 `main.S`）
- [ ] `B-riscv/main.S` 是自己手写的，覆盖了二维数组、递归、嵌套循环、break/continue、浮点
- [ ] 链接命令带了 `-nostdlib -static -mcmodel=medany -Wl,--no-relax,-Ttext=0x90000000 -Wl,-e,_start`
- [ ] case1、case2 在 `qemu-riscv64` 上都和期望输出一致
- [ ] 能解释那三个坑（入口点、`.attribute arch`、ABI 混用）的成因
- [ ] `.o` 与可执行文件的 `main` 反汇编对照有截图
- [ ] `B-riscv/build.sh` 能从空目录一键重建全部产物
- [ ] 报告第 3 章写完，第 5 章 `<!-- by B -->` 那段写完
- [ ] MLIR：拿到 A 的 `advanced-mlir/logs/l3.mlir`（若 A 卡住，自己跑 L1→L3 顶上，别干等）
- [ ] MLIR：L3.5 bufferization、L4、L5 跑通，`l5.ll` 已生成
- [ ] MLIR：把 `l5.ll` 和 A 手写的 `main.ll` 对照过，写进报告 4.3
- [ ] MLIR：报告 4.3 写完，4.4 里的 `<!-- by B -->` 那段写完
- [ ] MLIR：如果没装成，明确记下"为什么没做"
