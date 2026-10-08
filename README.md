# 编译原理 · 上机预备作业：了解编译器 / LLVM IR / RISC-V 汇编

两人小组作业。研究对象：**LLVM/Clang + RISC-V（rv64）**。
> 目标架构只做 **RISC-V**，不做 ARM。

## 分工（按"独立纵向流水线"切分，最大化并行、最小化交流）

| 成员 | 归属 lane | 负责的报告章节 | 主要交付物 |
|---|---|---|---|
| **A** | `lane/llvm` → `A-llvm/` | ①了解编译器工作过程 ②熟悉 LLVM IR 中间语言 | `A-llvm/main.ll`（手写）、各阶段产物 `.i/.ll/.S/.o`、`objdump`/`nm` 分析、pass 日志 |
| **B** | `lane/riscv` → `B-riscv/` | ③熟悉汇编语言 | `B-riscv/main.S`（手写）、RISC-V 目标文件与静态链接、`qemu-riscv64` 验证、反汇编对比 |
| A + B | `advanced-mlir/` | ④观察 AI 编译器 MLIR 中端处理过程 | **一人跑一半**：A 跑 L1→L3，B 跑 L3.5→L5，交接物 `advanced-mlir/logs/l3.mlir` |

**唯一需要当面沟通的环节**：开工前 30 分钟冻结接口（源程序 / 期望输出 / 报告骨架 / 环境）。
之后依靠 **目录独占 + PR 模板 + CI** 替代日常沟通，细节见 [`分工方案.md`](分工方案.md)。

## 目录约定（一个目录只有一个人有写权限）

```
common/          冻结区，两人都不改（要改先开 Issue）
A-llvm/          A 独占
B-riscv/         B 独占（含自实现运行库 sylib_ref.S）
advanced-mlir/   MLIR 进阶任务
doc/             报告与图片（图片按 fig-A-* / fig-B-* 命名）
tools/           自检脚本（只读，两人都可运行）
```

## 文档导航

| 文件 | 给谁看 | 内容 |
|---|---|---|
| [`三机环境搭建清单.md`](三机环境搭建清单.md) | **三个人各自照抄** | 从零装 WSL2 → 装工具链 → 配 Git → 克隆仓库 → **三机版本对齐**（含管理员机器的基准版本） |
| [`plan-A.md`](plan-A.md) | **A** | LLVM / clang 这条线的完整做法：阶乘+斐波那契示例 → 各阶段产物 → 手写 `.ll` → 写报告第 1、2 章 |
| [`plan-B.md`](plan-B.md) | **B** | RISC-V 汇编这条线的完整做法：交叉编译 → 手写 `.S` → 链接 qemu → 写报告第 3 章 |
| [`git与依赖安装指导.md`](git与依赖安装指导.md) | **A 和 B** | 环境自检、各自要装什么、Git 按场景查（提交/PR/冲突/撤销） |
| [`管理员手册.md`](管理员手册.md) | **仓库管理员（建议 A）** | 建仓库、分支保护、协作者权限、CI、日常巡检、急救表 |
| [`分工方案.md`](分工方案.md) | 两人都看一次 | 整体设计：为什么这样分工、目录怎么分、风险兜底、验收清单 |
| [`B-riscv/README.md`](B-riscv/README.md) | B | 自实现运行库说明与三条实测踩过的链接坑 |

**前提**：A、B、管理员**各用一台自己的 Windows 电脑**（都装 WSL2）。
因为不共用机器，每台机器要各自搭一遍环境——清单见 [`三机环境搭建清单.md`](三机环境搭建清单.md)，
搭完请跑 `bash tools/record_versions.sh` **三台互相对一下版本**。

**原则**：简单的事（看指导书的阶乘/斐波那契示例）**两个人各自独立做一遍**，
不对答案、不分工；只有一小部分真正共享的东西（`common/` 里的源程序和期望输出）才需要冻结一次。
进阶的 MLIR 要求两人共同完成，做法是**把 lowering 链从中间切开、用文件交接**，
而不是两个人坐在一起——这样各自都有真东西可写，但不用互相等。

## 快速开始

```bash
# 进入实验环境（WSL2 Ubuntu）：见 common/env.md 内的说明
cat common/env.md

# 四条自检命令，全部实测通过
bash common/verify_expected.sh   # 期望输出可复现（case1 PASS / case2 PASS）
bash tools/check_examples.sh     # 指导书的阶乘/斐波那契示例能否编译（A/B 两条路都试）
bash tools/check_laneA.sh        # A 线：预处理 / AST / LLVM IR / llc / 链接运行
bash tools/check_laneB.sh        # B 线：交叉编译 / RISC-V 目标文件 / 自实现运行库 / qemu
```

## 三个测试程序

| 程序 | 位置 | 用途 |
|---|---|---|
| 阶乘 | `common/examples/fact.c` | 指导书 1.3 节的第一个示例（cin/cout 改成 getint/putint）。A、B 各自独立跑一遍 |
| 斐波那契 | `common/examples/fib.c` | 指导书 1.3 节的第二个示例。同上 |
| 主测试程序 | `common/sysy_main.c` | 覆盖宏、全局数组、浮点、递归、嵌套循环、break/continue 等，是最终对答案的那个 |

## 环境已实测确认的事实（省得两人重复踩坑）

| 事实 | 影响 |
|---|---|
| WSL2 Ubuntu 26.04 已装好 `clang 21.1.8`、`llc`、`opt`、`lli`、`riscv64-unknown-elf-gcc 14.2`、`qemu-riscv64 10.2` | 不用再配环境 |
| clang 21 **不允许隐式函数声明** | `common/sysy_main.c` 已显式写出 SysY 运行库原型 |
| clang 21 默认 **opaque pointer**（实测 IR 中 `ptr` 144 次、`i32*` 0 次） | 手写 IR 必须用 `ptr` + `load i32, ptr %p`，不能照抄指导书的 `i32*` |
| `riscv64-unknown-elf-gcc` **没有 sysroot / libc**，实验指导里的链接命令**按原样会失败** | 必须加 `-nostdlib` 并提供 `_start`；本仓库已提供 `B-riscv/sylib_ref.S` |
| `libsysy_x86.a` / `libsysy_riscv.a` / `sylib.so` **本机都没有** | 从课程飞书群 `lib.tar.gz` 获取；A 线可先用等价桩函数自测 |
| **没有 `mlir-opt` / `mlir-translate` / `cmake`** | 进阶项需 `sudo apt install mlir-21-tools`（要交互输密码，agent 装不了） |

## 验收标准

两条 lane 都必须对 `common/testdata/case{1,2}.in` 运行后，与 `common/expected/case{1,2}.out`
**逐字节一致**：

```bash
diff <(你的程序 < common/testdata/case1.in) common/expected/case1.out
```

期望输出（已实测冻结）：

| 用例 | 输入 | 输出（6 行） |
|---|---|---|
| case1 | `6 4` | `44` `2` `120` `55` `55` `3` |
| case2 | `-9 25` | `-232` `1` `120` `55` `6` `3` |

## 提交物

1. GitHub 仓库链接（含 `master` 保护分支、两条 lane 分支、PR 记录、CI 绿）
2. 实验报告（`doc/report.md` 导出 PDF）：题目 / 摘要 / 关键词 / 引言 / 工作与结果 / 结论 / 参考文献
3. 本 README 的分工表即为分工说明

## 详细方案

👉 [`分工方案.md`](分工方案.md)：完整任务分解、时间表、命令清单、风险兜底、验收清单。
👉 [`doc/pdf_text.txt`](doc/pdf_text.txt)：指导书 PDF 的纯文本提取，便于复制符号与命令。
👉 [`B-riscv/README.md`](B-riscv/README.md)：B 线的运行库说明与三条实测坑。
