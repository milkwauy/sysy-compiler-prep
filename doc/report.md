# 了解编译器、LLVM IR 编程及 RISC-V 汇编编程

> **写作规则（两人必须遵守，否则会产生"改别人标题"的冲突）**
> 1. 标题层级、编号一律**不要动**；只往自己负责的小节里填内容。
> 2. 图片按 `doc/figures/fig-A-*.png` 与 `fig-B-*.png` 命名，天然不冲突。
> 3. 表号：A 用 `表 A-1`，B 用 `表 B-1`。不确定的观测结果一律标注"待复核"，不要删别人的内容。
> 4. 引言 / 结论由两人各写一段（标记 `<!-- by A -->` / `<!-- by B -->`），merge owner 拼接。

**成员与分工**

| 成员 | 姓名 | 学号 | 负责章节 | 工作占比 |
|---|---|---|---|---|
| A |  |  | 第 1、2 章 |  |
| B |  |  | 第 3 章 |  |

---

## 摘要

（merge owner 在定稿时写，最后写：本文以 LLVM/Clang 为研究对象，…，以 RISC-V rv64 为目标，
手工编写了与 SysY 源程序等价的 LLVM IR 与汇编程序，链接 SysY 运行库并通过 `qemu-riscv64`
验证了运行结果；进一步观察了 MLIR 中端的逐层 lowering 过程。）

**关键词**：编译过程；LLVM IR；RISC-V 汇编；SysY；MLIR；方言 lowering

---

## 1 语言处理系统的完整工作过程

> **负责人：A**

### 1.1 整体流程与实验对象

- 研究对象：`common/sysy_main.c`（覆盖宏、全局变量、全局数组、浮点、递归、嵌套循环等特性）
- 流程图：`doc/figures/fig-A-1-pipeline.png`
- 四个阶段的输入输出对照表：`表 A-1`

| 阶段 | 输入 | 输出 | 对应命令 |
|---|---|---|---|
| 预处理器 | `sysy_main.c` | `main.i` | `clang -E` |
| 编译器 | `main.i` | `main.s` / `main.ll` | `clang -S` |
| 汇编器 | `main.s` | `main.o`（可重定位） | `clang -c` |
| 链接器 | `main.o` + 库 | 可执行文件 | `clang` |

### 1.2 预处理器做了什么

（宏展开前后对比、`#include` 展开、注释删除、行号标记；贴 `-E` 与 `-E -P` 的 diff 片段）

### 1.3 编译器做了什么（六阶段的细致观察）

#### 1.3.1 词法分析
（贴 `clang -E -Xclang -dump-tokens` 输出片段，指出标识符/关键字/字面量/运算符各类 token）

#### 1.3.2 语法分析
（贴 `clang -E -Xclang -ast-dump` 片段，指出与 SysY 文法的对应：FuncDef / Block / Stmt）

#### 1.3.3 语义分析
（类型检查、符号表、隐式类型转换：`(float)a / 2.0` 与 `(int)fr` 的位置）

#### 1.3.4 中间代码生成
（`-S -emit-llvm`，与第 2 章呼应）

#### 1.3.5 代码优化
（`llc -print-before-all -print-after-all` 日志；指出 mem2reg / instcombine 前后 IR 变化）

#### 1.3.6 代码生成
（`.ll` → `main.s` → `main.o`，贴 `llc` 与 `objdump -d` 对照）

### 1.4 汇编器做了什么

（汇编 → 机器码映射关系；`objdump -d`、`nm`、`readelf` 观察符号表与重定位；
说明"可重定位目标文件"为何还不能运行）

### 1.5 链接器做了什么

（地址绑定、符号解析、库的合并；对比 `.o` 与可执行文件反汇编的地址差异；
`-static` 与动态链接的体积/依赖差异）

### 1.6 编译选项的对比实验（探索部分）

| 选项 | 目标文件大小 | 运行时间 | IR 指令条数 |
|---|---|---|---|
| `-O0` |  |  |  |
| `-O1` |  |  |  |
| `-O2` |  |  |  |
| `-O3` |  |  |  |

（结论：优化对 IR、汇编、目标大小与实际运行时间的影响）

---

## 2 LLVM IR 中间语言

> **负责人：A**

### 2.1 LLVM IR 的三层表示形态

（内存表示 / bitcode 二进制 / 文本 `.ll`；`llvm-as` 与 `llvm-dis` 互转实验）

### 2.2 LLVM IR 的结构要素与 SysY 的对应

| LLVM IR 概念 | 说明 | SysY 对应 |
|---|---|---|
| `module` | 单个编译单元 | `CompUnit` |
| `define @f(...)` | 函数定义 | `FuncDef` |
| `declare` | 外部函数声明 | 运行库函数 |
| `basic block` + terminator | 基本块与终结指令 | `Block` / `Stmt` |
| `%x = alloca i32` | 栈上分配 | 局部变量声明 |
| `load` / `store` | 读写内存 | 赋值 `LVal = Exp` |
| `icmp` + `br i1` | 比较与条件分支 | `if` / `while` |
| `@g = global i32 0` | 全局变量 | 顶层 `Decl` |

### 2.3 手写 LLVM IR 程序（核心工作）

（贴 `A-llvm/main.ll` 全文或关键片段，并逐段讲解：如何用基本块表达 `for` 嵌套循环、
如何用 `getelementptr` 访问 `mat[i][j]`、如何表达 `break`/`continue` 对应的跳转）

### 2.4 Opaque Pointer（不透明指针）的影响

（对比旧式 `i32*` 与新式 `ptr`；说明 `load i32, ptr %p` 中类型必须写在指令里的原因；
对编写数组/指针相关 IR 的简化作用）

### 2.5 与运行库的链接和执行验证

（`clang -o main main.ll libsysy_x86.a` 与 `lli -load=./sylib.so main.ll` 两种方式；
贴 case1/case2 的 `diff` 通过截图）

---

## 3 RISC-V 汇编语言

> **负责人：B**

### 3.1 RISC-V 编程所需的基础知识

（rv64i + M 扩展；寄存器组与 ABI 别名 `a0-a7 / ra / sp / s0`；调用约定：参数→`a0-a7`，
返回值→`a0`，返回地址→`ra`；栈向低地址增长且 **16 字节对齐**；`.attribute` 声明）

### 3.2 手写 RISC-V 汇编程序（核心工作）

（贴 `B-riscv/main.S` 全文或关键片段并逐段讲解：
`gcd` 的 `while` + `remw`；`fib` 的递归与栈帧保存 `ra`；`fill_mat` 的双层循环与 `break/continue`
标签；`mat[i][j]` 的地址计算 `(i*3+j)*4`；全局数组在 `.sbss` 段的定义）

### 3.3 汇编器做了什么

（`.s` → `.o`；`objdump -d` 反汇编结果；`readelf -r` 显示的重定位项；
符号表 `nm` 中的 `U`（未定义）/ `T`（已定义）标记；`-Wl,--no-relax` 的作用）

### 3.4 链接器做了什么

（`.o` → 可执行文件：重定位被填实、运行库符号被解析、`-Ttext=0x90000000` 设定的基址；
`.o` 与可执行文件同一函数的反汇编对比）

### 3.5 内存模型与寻址方式

（`medlow` vs `medany`；`lui+addi` / `auipc+addi` / `la` / `lla` 的区别与适用范围；
为什么 `lui` 处理不了 `0x80000000` 以上的地址，会出现 `R_RISCV_HI20` 截断错误）

### 3.6 运行验证

（静态链接 `libsysy_riscv.a` + `qemu-riscv64`；贴 case1/case2 的 `diff` 通过截图；
若有"自实现运行库"的情况在此说明）

### 3.7 与编译器生成汇编的对比（探索部分）

（`clang --target=riscv64-unknown-elf -O0/-O2 -S` 与手写版的指令条数、寄存器使用、
栈帧大小、是否内联等方面的差异表）

---

## 4 AI 编译器 MLIR 中端处理过程（进阶）

> **负责人：两人分工执笔。4.1、4.2 由 A 写；4.3 由 B 写；4.4 两人各写一段（用 `<!-- by A -->` / `<!-- by B -->` 标记）。**
> **交接点**：`advanced-mlir/logs/l3.mlir`，由 A 生成后交给 B，之后 A 不再改动。

### 4.1 MLIR 的多级方言与渐进式降低

<!-- by A -->
（与 LLVM IR 单层中间表示的本质区别：LLVM IR 在同一抽象层内用 pass 串变换；
MLIR 通过 dialect conversion 跨抽象层级下降，每层保留该层最合适的信息）

### 4.2 VecAdd 示例的逐层 lowering 观察（L1 → L3，A 负责）

| 层级 | 命令/Pass | 方言 | 该层"看得见"的信息 | 该层"看不见"的信息 |
|---|---|---|---|---|
| L0 起点 | — | linalg / tensor | `linalg.add` 算子语义、张量形状 | 循环、内存布局 |
| L1 | `linalg-generalize-named-ops` | linalg.generic / tensor | 索引映射、迭代维度 | 算子名字本身 |
| L2 | `convert-linalg-to-loops` | linalg / scf | 循环边界、下标计算 | 张量整体语义 |
| L3 | `convert-scf-to-cf` | scf / cf | 结构化控制流 → 基本块 + 条件跳转 | 高层算子语义 |

（每层贴 `advanced-mlir/logs/lN.mlir` 的关键片段，并回答三个问题：
①还能看见"两个向量相加"吗？②新出现了什么概念？③上一层丢了什么信息？）

### 4.3 继续降低到 LLVM 方言（L3 → L5，B 负责）

| 层级 | 命令/Pass | 方言 | 该层"看得见"的信息 | 该层"看不见"的信息 |
|---|---|---|---|---|
| L3.5 | `one-shot-bufferize` | memref | **内存位置、缓冲区**（值语义 → 内存语义的跨越） | 张量值语义 |
| L4 | `convert-to-llvm` | memref / llvm | 指针、内存、函数调用 | 形状与算子语义 |
| L5 | `mlir-translate --mlir-to-llvmir` | LLVM 方言 | 与第 2 章完全一致 | 全部高层信息 |

（重点写两件事：①bufferization 为什么是必需的跨越——`tensor` 没有地址，`memref` 有；
②把 `l5.ll` 与 A 手写的 `main.ll` 对照，讨论"编译器降出来的 LLVM IR"和"人写的 LLVM IR"
结构上像在哪、不像在哪）

### 4.4 结论

<!-- by A -->
（多级方言如何让硬件无关优化与硬件相关 lowering 在中端共存）

<!-- by B -->
（Ascend NPU IR 为何选择以 MLIR 作为昇腾硬件的抽象层；与 LLVM IR 单层方案的对比取舍）

---

## 5 结论

<!-- by A -->
（总结基础部分的工作与收获）

<!-- by B -->
（总结汇编部分的工作与收获，及进阶部分的发现）

---

## 参考文献

1. 编译原理实验指导《了解编译器，LLVM IR 编程及汇编编程》，2020–2026.
2. LLVM Language Reference Manual. https://llvm.org/docs/LangRef.html
3. LLVM Programmer's Manual. https://llvm.org/docs/ProgrammersManual.html
4. The RISC-V Instruction Set Manual, Volume I: Unprivileged ISA.
5. MLIR Documentation — Quickstart / Dialect Conversion. https://mlir.llvm.org/
6. SysY 语言定义与运行时库说明（课程资料）.
