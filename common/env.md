# 实验环境（两人共用约定）

## 主环境：WSL2 + Ubuntu（本机已就绪）

在 Windows 的 PowerShell / CMD 里：

```powershell
wsl -d Ubuntu
```

进入后建议把工作目录软链到 home 下，避免每次敲长中文路径：

```bash
ln -sfn "/mnt/c/Users/milkw/Desktop/编译系统作业/上机预备作业" ~/prep
cd ~/prep
```

> ⚠️ WSL 里读 `/mnt/c` 比原生文件系统慢。跑大量编译（如 LLVM pass 日志）时，
> 可先 `cp -r ~/prep ~/work && cd ~/work`，完事再拷回。

## 本机已确认可用的工具

| 工具 | 版本/路径 | 用途 |
|---|---|---|
| `clang` | 21.1.8 (`/usr/bin/clang`) | 预处理、AST/token dump、生成 LLVM IR、交叉编译 |
| `llc` | 已装 | LLVM IR → 目标汇编 / 目标文件 |
| `opt` | 已装 | 单 pass 观察、IR 变换 |
| `lli` | 已装 | JIT 直接运行 LLVM IR |
| `llvm-as` / `llvm-dis` | 已装 | `.ll` ↔ `.bc` 互转 |
| `riscv64-unknown-elf-gcc` | 已装 | 汇编器 + 链接器（rv64，静态） |
| `qemu-riscv64` | 已装 | 在 x86 主机上运行 RISC-V 程序 |
| `riscv64-unknown-elf-objdump/nm/readelf` | 已装 | 反汇编、符号表、重定位分析 |

**尚未安装**：`mlir-opt`（进阶任务用）、`cmake`。安装方式：

```bash
sudo apt update && sudo apt install -y mlir-21-tools cmake
# 若 apt 源里没有对应版本，用 LLVM 官方源：
#   https://apt.llvm.org/   或改用 Docker: ghcr.io/llvm/llvm-project
```

## 需要另外准备的文件

SysY 运行时库（课程飞书群资料 `lib.tar.gz`），解出后放到：

```
A-llvm/libsysy/libsysy_x86.a    # A 线：x86 上验证 LLVM IR
A-llvm/libsysy/sylib.so         # A 线：lli JIT（可选）
B-riscv/libsysy/libsysy_riscv.a # B 线：RISC-V 上链接
```

如果暂时拿不到，**不要停工**：B 线可用 `riscv64-unknown-elf-gcc` 自己实现
`getint/putint/putch`（Linux syscall 或 `-static` + 手写 `_start`），
报告中说明"自实现运行库"，反而是加分内容。

## 关键编译参数（RISC-V 方向，来自实验指导 4.2 节）

```
-mcmodel=medany           # 内存模型；避免 R_RISCV_HI20 被截断的重定位错误
-Wl,--no-relax            # 关闭链接器松弛，指令与汇编一一对应，便于对照分析
-Ttext=0x90000000         # 程序基址（lui+addi 的 32 位地址构造到不了太高地址）
-static                   # 静态链接，qemu 用户态直接可跑
.attribute stack_align, 16    # 栈 16 字节对齐（实验作业硬性要求）
.attribute unaligned_access, 0
```
