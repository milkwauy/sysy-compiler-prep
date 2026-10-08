# A / B 依赖安装与 Git 使用指导

> 这份文档两个人共用。**第 1 章两人都看，第 2 章 A 看 2.1、B 看 2.2，第 3 章 Git 部分每人都要会。**
>
> **前提**：A、B、管理员**各用一台自己的 Windows 电脑**，都有管理员权限，装什么自己装。
> 所以每台机器都要各自把环境搭一遍——完整清单见 [`三机环境搭建清单.md`](三机环境搭建清单.md)，
> 那份文档是**照着从零开始搭**的顺序写的，本文则按"A 需要什么 / B 需要什么 / Git 怎么用"来查。
>
> 下面的命令都在**管理员那台机器上实际验证过**。当前状态：

| 工具 | 管理员这台机器的状态 | 在哪 | A / B 那边 |
|---|---|---|---|
| Git | ✅ 2.55.0.windows.3 | Windows | 各自装，版本接近即可 |
| GitHub 凭据 | ✅ 账号 `milkwauy` 已存在凭据管理器 | Windows | **各自配自己的账号** |
| `gh` 命令行 | ❌ 未安装 | — | 用网页操作完全可以 |
| WSL2 Ubuntu | ✅ 26.04 LTS | Windows 内 | 各自装 |
| clang / llc / opt / lli | ✅ 21.1.8 | WSL | **必须对齐大版本**（15 是 `ptr` 写法的分界） |
| riscv64-unknown-elf-gcc | ✅ 14.2.0 | WSL | B 必装，A 建议装 |
| qemu-riscv64 | ✅ 10.2.1 | WSL | B 必装 |
| `mlir-opt` / `mlir-translate` | ❌ 未安装（源里有 `mlir-21-tools`） | WSL | 进阶任务才需要 |
| 课程 SysY 运行库 | ❌ 需自行获取 | 飞书群资料 | 各自放一份，或用替代方案 |

> **每个人的机器都要各自搭一遍。** 搭完请跑 `bash tools/record_versions.sh`
> 把版本贴出来互相对一下——各装各的环境时，**版本漂移是唯一需要留意的真实风险**。

---

## 目录

- [第 1 章 · 两人共同的准备](#第-1-章--两人共同的准备)
- [第 2 章 · 各自额外要装的东西](#第-2-章--各自额外要装的东西)
- [第 3 章 · Git 使用指导（按场景查）](#第-3-章--git-使用指导按场景查)
- [第 4 章 · 命令速查表](#第-4-章--命令速查表)
- [第 5 章 · 出问题时的自救](#第-5-章--出问题时的自救)

---

## 第 1 章 · 两人共同的准备

### 1.1 先跑通环境自检（10 秒，确认一切正常）

打开 PowerShell：

```powershell
wsl -d Ubuntu
```

进到仓库目录（下面用 `~/prep` 这个软链，省得每次敲中文长路径）：

```bash
ln -sfn "/mnt/c/Users/milkw/Desktop/编译系统作业/上机预备作业" ~/prep
cd ~/prep
```

然后跑这四条自检，**全绿说明环境没问题**：

```bash
bash common/verify_expected.sh    # 应输出 case1 PASS / case2 PASS
bash tools/check_examples.sh      # 阶乘/斐波那契示例两边都能编译
bash tools/check_laneA.sh         # 最后两行 case1 PASS / case2 PASS
bash tools/check_laneB.sh         # 自实现运行库冒烟测试 PASS
```

### 1.2 配置 Git 换行符（**不做这一步会踩大坑**）

仓库里已经有 `.gitattributes`，它规定了脚本和期望输出一律用 LF 换行。
但为了保险，**在 WSL 里也关掉 Git 的自动转换**：

```bash
git config --global core.autocrlf false
git config --global core.quotepath false
```

**为什么必须做**：如果不关，Git 可能把 `tools/*.sh` 转成 CRLF，然后你在 WSL 里跑就会报：

```
bash: ./tools/check_laneA.sh: /bin/bash^M: bad interpreter: No such file or directory
```

更阴的是它还会把 `common/expected/*.out` 转坏，导致 `diff` 认为**每一行都不一样**——
程序明明是对的，验收却全 FAIL，两个人还会互相怀疑。

> 已经有 `.gitattributes` 兜底了，这里只是再加一道保险。

### 1.3 配置 Git 身份（三台机器各自配一次）

```powershell
# 在 Windows PowerShell 里执行
git config --global user.name  "你的名字"
git config --global user.email "你的GitHub注册邮箱"
git config --global core.quotepath false
git config --global core.autocrlf false
```

**关于主分支名：本组用 `master`，不用 `main`。**

好消息是**通常什么都不用配**：实测本机 Windows 侧（Git 2.55.0）和 WSL 侧（Git 2.53.0）
**都没配** `init.defaultBranch`，所以 `git init` 建出来的就是 `master`。

开工前查一下：

```powershell
git config --global init.defaultBranch     # 无输出 = 默认就是 master
```

- **无输出** → 什么都不用做。
- **输出 `main`** → 删掉它：`git config --global --unset init.defaultBranch`

**最稳的写法是不依赖默认值**：直接用 `git init -b master`，永远不会建错。

**提交完验证一下是谁**：

```powershell
git log -1 --format="%an <%ae>"
```

**因为三个人各用一台自己的电脑**，上面这些配置只在自己机器上生效，
**不存在"提交记在别人名下"的问题**，也不需要来回切换身份。

> **别忘了 WSL 里也配一遍**。Windows 侧和 WSL 侧是**两套独立的 Git 配置**，
> 只配一边的话，在另一边提交时作者信息就是空的或错的：
> ```bash
> # 在 WSL 里
> git config --global user.name  "你的名字"
> git config --global user.email "你的GitHub注册邮箱"
> git config --global core.autocrlf false
> git config --global core.quotepath false
> ```

如果发现提交记错了人，见第 3.9 节。

### 1.4 把仓库克隆到自己的机器

**建议克隆到 WSL 的家目录 `~/prep`，不要放在 `/mnt/c/...` 下面。** 三个理由：

1. WSL 访问 `/mnt/c` 是跨文件系统的，编译大量文件时**慢好几倍**；
2. 中文路径容易在脚本和终端里出编码问题；
3. 三台机器统一成 `/home/<用户名>/prep`，谁都能直接照抄命令。

```bash
# 在 WSL 里
cd ~
git clone https://github.com/milkwauy/sysy-compiler-prep.git prep
cd ~/prep

git remote -v                  # 确认指向正确
git branch --show-current      # 确认在哪个分支

git switch lane/llvm           # A
# 或 git switch lane/riscv     # B
# 管理员：git switch master
```

第一次克隆会弹浏览器授权（HTTPS 方式），授权一次之后就不用再输密码了。

克隆完**先跑一遍 1.1 的自检**，确认环境没问题再开始干活：

```bash
bash common/verify_expected.sh
bash tools/check_examples.sh
bash tools/record_versions.sh   # 把版本输出贴给另外两人（见下）
```

> **搭完一定要做这一步**：跑 `bash tools/record_versions.sh`，
> 把自己机器的工具链版本贴到群里或 Issue 里，三个人互相对一下。
> 因为各装各的环境，**版本漂移是跨设备方案唯一的真实风险**——
> 尤其是 `clang` 的大版本，它决定手写 LLVM IR 时用 `ptr` 还是 `i32*`。
> 完整对照方法见 [`三机环境搭建清单.md`](三机环境搭建清单.md) 第 4 节。

### 1.5 可选但有帮助的小工具

```bash
# 在 WSL 里（需要输密码）
sudo apt update
sudo apt install -y make tree graphviz   # tree 看目录结构，dot 把 CFG 画成图
```

`graphviz` 是给 A 用的：GCC 的 `-fdump-tree-all-graph` 会生成 `.dot` 文件，
用 `dot -Tpng` 就能变成报告里的控制流图。

---

## 第 2 章 · 各自额外要装的东西

### 2.1 A 要装的（LLVM / clang 线）

**结论：什么都不用装，已经全齐了。** 当前 WSL 里的版本：

```bash
clang --version      # Ubuntu clang version 21.1.8
llc --version        # LLVM 21.1.8，已注册 riscv32 / riscv64 目标
opt --version
lli --version
```

顺便确认一下这几个配套工具也在（一般跟着 llvm 包一起装）：

```bash
for t in llvm-as llvm-dis llvm-config objdump nm readelf; do
  printf "%-14s %s\n" "$t" "$(command -v $t || echo 未安装)"
done
```

**如果 `llvm-as` / `llvm-dis` 缺失**：

```bash
sudo apt install -y llvm          # 会带上这一组工具
```

**A 还需要的、但装不了的东西**：课程提供的 `libsysy_x86.a` 和 `sylib.so`
（在飞书群的 `lib.tar.gz` 里）。没拿到之前**不要停工**，
`tools/check_laneA.sh` 会自动用等价的桩函数（`stub.c`）顶上，
照样能验证你的 LLVM IR 跑出正确结果——报告里注明"使用等价桩函数验证"即可。

拿到之后放到这两个位置：

```
A-llvm/libsysy/libsysy_x86.a     # clang 链接用
A-llvm/libsysy/sylib.so          # lli JIT 用（可选）
```

（这两个目录在 `.gitignore` 里，不会把二进制库提交进仓库。）

### 2.2 B 要装的（RISC-V 汇编线）

**结论：也基本齐了。** 当前 WSL 里的版本：

```bash
riscv64-unknown-elf-gcc --version   # 14.2.0
qemu-riscv64 --version              # 10.2.1
```

配套工具确认：

```bash
for t in riscv64-unknown-elf-as riscv64-unknown-elf-ld \
         riscv64-unknown-elf-objdump riscv64-unknown-elf-nm \
         riscv64-unknown-elf-readelf; do
  printf "%-34s %s\n" "$t" "$(command -v $t || echo 未安装)"
done
```

缺哪一个就装（通常是同一个包里的）：

```bash
sudo apt install -y gcc-riscv64-unknown-elf qemu-user
```

#### ⚠️ B 必须知道的一件重要的事

本机这个 `riscv64-unknown-elf-gcc` 是**裸机（bare-metal）工具链**，实测确认：

```
-print-sysroot              → 空
-print-file-name=libc.a     → 只回显 "libc.a"，找不到
crt0.o / libgloss.a         → 都不存在
```

**直接后果**：实验指导书 4.3 节那条链接命令**按原样会失败**，报错是

```
ld: cannot find crt0.o: No such file or directory
ld: cannot find -lc: No such file or directory
ld: cannot find -lgloss: No such file or directory
```

**所以你必须用 `-nostdlib`，并提供自己的运行库和 `_start`。**
仓库里已经写好了实测通过的运行库 [`B-riscv/sylib_ref.S`](B-riscv/sylib_ref.S)，
用 `ecall` 直接调 Linux 系统调用（`write`=64、`read`=63、`exit`=93）实现
`getch/getint/putch/putint` 和 `_start`，5 组输入输出实测全部正确。

实测通过的完整链接命令：

```bash
riscv64-unknown-elf-gcc -nostdlib -static -mcmodel=medany \
    -Wl,--no-relax,-Ttext=0x90000000 -Wl,-e,_start \
    B-riscv/obj/sylib_ref.o B-riscv/obj/main.o -o B-riscv/obj/main
```

三个参数的作用和踩过的坑，详见 [`plan-B.md`](plan-B.md) 第四节。

**你另外需要的**：课程提供的 `libsysy_riscv.a`（同样在 `lib.tar.gz` 里）。
拿到就放 `B-riscv/libsysy/`。但**没有它也能完成全部任务**，用自实现运行库即可，
报告里说明这一点反而是加分内容。

### 2.3 MLIR（两人都要，**各自在自己机器上装**）

**实测确认**：Ubuntu 26.04 的 apt 源里**有** `mlir-21-tools`，直接装即可。

```bash
# 在 WSL 里，需要输密码
sudo apt update
sudo apt install -y mlir-21-tools
```

装完验证：

```bash
mlir-opt --version
mlir-translate --version
mlir-opt --help | head -20
```

然后跑 MLIR 自检：

```bash
bash tools/check_mlir.sh
```

**装不上或者版本不对怎么办**：

| 情况 | 处理 |
|---|---|
| apt 里没有 `mlir-21-tools` | 试 `mlir-19-tools`、`mlir-18-tools`，或 `apt search mlir` 看有哪些 |
| 想要指定版本 | 用 LLVM 官方源 <https://apt.llvm.org/> |
| 不想动系统环境 | 用 Docker：你机器上已装 Docker，可跑 `ghcr.io/llvm/llvm-project` 镜像 |
| 实在装不上 | **跳过这 1 分的进阶项。** 基础 4 分完全不受影响 |

**版本差异要留意**：本机会装到 MLIR 21，而课程 PPT 里 Ascend NPU IR 基于 LLVM 15 时代的 MLIR。
**pass 名字在不同版本之间改过**。报 `unknown pass` 时：

```bash
mlir-opt --help | grep -i <关键词>      # 查你这个版本实际叫什么
```

报告里如实写一句版本差异，这是有价值的观察，不算错。

### 2.4 cmake（一般用不到）

当前**没有安装**。只有当你想自己写 MLIR pass、或者编译 LLVM 源码时才需要：

```bash
sudo apt install -y cmake ninja-build
```

本作业**不需要**。别为了它耽误主线。

---

## 第 3 章 · Git 使用指导（按场景查）

> 不要求你背 Git。**遇到什么情况就查哪一节。**
>
> 管理员另有一份 [`管理员手册.md`](管理员手册.md)，讲的是仓库设置和合并流程；
> 这一章讲的是**你日常怎么提交自己的活**。

### 3.0 一分钟了解本组的 Git 规矩

| 规矩 | 内容 |
|---|---|
| 分支 | A 只用 `lane/llvm`，B 只用 `lane/riscv`。**永远不直接往 `master` 提交** |
| 目录 | A 只改 `A-llvm/`，B 只改 `B-riscv/`，MLIR 各写各的文件 |
| 公共文件 | `common/` 和 `doc/report.md` 的标题**不许改**（各写各自的小节内容） |
| 提交信息 | 统一格式：`[llvm] xxx` 或 `[riscv] xxx` |
| 同步方式 | 用 PR 合并，不在群里喊 |

### 3.1 第一次用：把仓库拿到本地

**情况一：用管理员这台电脑**（仓库已经在了）

```powershell
cd "C:\Users\milkw\Desktop\编译系统作业\上机预备作业"
git status
```

**情况二：在自己电脑上**

```powershell
git clone https://github.com/milkwauy/sysy-compiler-prep.git
cd sysy-compiler-prep

# 切到自己的分支
git switch lane/llvm        # A
git switch lane/riscv       # B
```

### 3.2 每天的固定动作

```powershell
git switch lane/llvm              # 1. 切到自己的分支（B 换成 lane/riscv）

git pull                          # 2. 先拉一下，看有没有别人的更新

# 3. 干活……写代码、跑测试

git status                        # 4. 看改了哪些文件
git add -A                        # 5. 全部加入暂存区
git status                        # 6. 再确认一次清单
git commit -m "[llvm] 生成 main.ll 并通过 case1"    # 7. 提交

git push                          # 8. 推上去
```

**推之前一定要先跑本地自检**（具体命令见 3.4 节），本地绿了 CI 基本就绿。

### 3.3 提交信息怎么写

统一格式，一眼能看出是谁的活：

```bash
# A 的
git commit -m "[llvm] 预处理产物与 token/AST 记录"
git commit -m "[llvm] 手写 main.ll，llvm-as 校验通过"
git commit -m "[llvm] case1/case2 全部 PASS"

# B 的
git commit -m "[riscv] 交叉编译参考汇编与反汇编留存"
git commit -m "[riscv] 手写 main.S，汇编通过"
git commit -m "[riscv] 链接自实现运行库，qemu 两个用例 PASS"

# MLIR（各自标自己负责的层）
git commit -m "[mlir] A: L1-L3 逐层降低产物"
git commit -m "[mlir] B: L3.5-L5 与 l5.ll"
```

**不要写** `update`、`修改`、`fix`、`123` 这种——助教靠提交记录看工作量，
信息量为零的提交等于白干。

### 3.4 每次 push 之前的自检清单

```powershell
# 1. 现在在正确的分支上吗？（不能是 main）
git branch --show-current

# 2. 有没有把不该提交的东西加进来？
git status --short
# 看到 .o / .exe / .a / .pdf 就要停下来！

# 3. 本次提交的作者是我吗？
git log -1 --format="%an <%ae>"
```

```bash
# 4. 在 WSL 里跑自检（必须全绿）
bash common/verify_expected.sh
bash tools/check_laneA.sh        # A 跑这个
bash tools/check_laneB.sh        # B 跑这个
```

### 3.5 开 PR（Pull Request）

每天至少开一次，在网页上操作：

1. 打开仓库页面，会看到黄条提示 "lane/llvm had recent pushes" → 点 **Compare & pull request**
   （或者点 **Pull requests** → **New pull request**，base 选 `master`，compare 选自己的分支）
2. 标题写成 `[llvm] xxx` 或 `[riscv] xxx`
3. **把模板里的三行填上**（这是必填的）：
   ```
   1. 编译命令：
   2. 运行命令：
   3. diff 期望输出结果：
   ```
4. 等 CI 跑完。绿了就等管理员合并；红了就自己修完再 push（**同一个 PR 会自动更新**，不用重开）

### 3.6 分支落后 `master` 了怎么办

如果 PR 页面提示 "This branch is out-of-date with the base branch"，或者你自己发现
`master` 有了新东西而你的分支没有：

```powershell
git switch lane/llvm          # 确保在自己的分支上
git fetch origin
git rebase origin/master        # 把自己的提交"叠"到最新的 master 上面

# 如果 rebase 过程报冲突，见 3.7 节

git push --force-with-lease   # 注意：rebase 之后需要强推，但要用 --force-with-lease
```

> **为什么用 `--force-with-lease` 而不是 `--force`**：
> 前者会在别人已经推过新东西时拒绝执行，防止你不小心覆盖掉别人的提交。安全得多。
>
> **只在自己的 lane 分支上这么干。`master` 上永远不强推。**

### 3.7 冲突了怎么办（`CONFLICT`）

冲突长这样：

```
CONFLICT (content): Merge conflict in doc/report.md
Automatic merge failed; fix conflicts and then commit the result.
```

**先别慌，先想清楚一件事：你是不是动了不该动的地方？**
本组目录是独占的，正常情况下**不应该有冲突**。真出现冲突，八成是：

- 双方都改了 `common/` 里的文件 —— **这是违反规矩的**，应该去开 Issue
- 双方都改了 `doc/report.md` 的同一段 —— 各写各自的小节就不会有这问题
- 双方都改了 `advanced-mlir/` 的同一个文件 —— 按 §6 分工，文件名不该重叠

**处理步骤**：

```powershell
git status                    # 看哪些文件冲突了

# 打开冲突文件，会看到这样的标记：
#   <<<<<<< HEAD
#   你的内容
#   =======
#   对方的内容
#   >>>>>>> origin/master
#
# 手动改成你想要的样子，把这三行标记全删掉

git add <改好的文件>
git rebase --continue         # 如果是 rebase 过程中
# 或者
git commit                    # 如果是 merge 过程中

# 想放弃这次合并、回到干净状态：
git rebase --abort
```

**如果冲突涉及的是别人的代码，不要自己猜着改。** 在 Issue 里说清楚，让写那部分的人处理。

### 3.8 撤销操作（后悔药）

```powershell
# 改错了，还没 add —— 丢弃工作区的修改
git restore <文件>                 # 单个文件
git restore .                      # 全部（谨慎！）

# 已经 add 了，想取消暂存
git restore --staged <文件>

# 已经 commit 了，想撤销提交但保留改动
git reset --soft HEAD~1

# 已经 commit 了，想把改动也一起丢掉
git reset --hard HEAD~1            # 谨慎！改动会消失

# 想看看刚才干了什么
git reflog                         # 救命用的，能找回大部分误操作
```

### 3.9 提交记错人了怎么办

**三个人各用一台电脑，正常情况下不会发生。** 真出现了，八成是某台机器上
`user.name` / `user.email` 没配或配错了（Windows 侧和 WSL 侧要各配一次）。

**先检查**：

```powershell
git config --global user.name
git config --global user.email
git log -1 --format="%an <%ae>"
```

**改对之后再修正最近一次提交**：

```powershell
# 只影响最近一次提交、且还没 push
git config --global user.name  "正确的名字"
git config --global user.email "正确的邮箱"
git commit --amend --reset-author --no-edit

# 已经 push 了
git push --force-with-lease
```

**如果好几个提交都记错了**：最省事的做法是**不改历史**，
在报告的分工说明里直接写清"由于环境配置问题，前 N 个提交的作者信息有误"。
**诚实说明比伪造记录好**——助教看的是实际工作量，不是提交名字。

> **不要为了改作者去重写整个历史**（`git filter-repo` 之类），
> 那会强制另外两个人重新克隆，得不偿失。

### 3.10 不要把大文件提交进仓库

`.gitignore` 已经排除了编译产物和运行库。但你自己产生的别的文件要注意：

```powershell
# 看看哪些文件大（找出超过 1MB 的）
git ls-files | ForEach-Object {
  $f = Get-Item $_ -ErrorAction SilentlyContinue
  if ($f -and $f.Length -gt 1MB) { "{0,10:N0}  {1}" -f $f.Length, $_ }
}
```

**提醒**：`A-llvm/analysis/passes.log` 可能非常大（`-print-before-all` 的输出很吓人），
它已经被 `.gitignore` 排除了。如果你想保留它，**只截取关键片段到 `A_notes.md` 里**，
不要把整个 log 提交进去。

### 3.11 绝对不要做的四件事

| ❌ 不要做 | 原因 |
|---|---|
| 直接往 `master` 提交或强推 | 保护规则会拒绝；就算绕过了也会打乱别人的分支 |
| 在 GitHub 网页上直接编辑文件 | 会造成远程和本地历史分叉，别人 pull 时一堆麻烦 |
| 修改 `common/` 里的文件 | 另一个人依赖它，改了会让他白跑一遍。要改就开 Issue |
| 修改 `doc/report.md` 的章节标题 | 标题是两人共用的，改了必然撞车 |

---

## 第 4 章 · 命令速查表

### Git 日常

| 我想干什么 | 命令 |
|---|---|
| 看当前状态（简短） | `git st` （别名，见下）或 `git status --short --branch` |
| 看分支图 | `git lg`（别名）或 `git log --oneline --graph --decorate --all` |
| 看最后一次提交改了啥 | `git last`（别名）或 `git log -1 --stat` |
| 我在哪个分支 | `git branch --show-current` |
| 切分支 | `git switch lane/llvm` |
| 拉最新 | `git pull` |
| 拉所有远程分支信息 | `git fetch --all --prune` |
| 看远程地址 | `git remote -v` |
| 提交 | `git add -A && git commit -m "[llvm] xxx"` |
| 推 | `git push` |
| 看我改了多少行 | `git diff --stat` |
| 看某个文件的历史 | `git log --oneline -- A-llvm/main.ll` |
| 最后一次提交的作者 | `git log -1 --format="%an <%ae>"` |

**先把别名配上，能省很多事**：

```powershell
git config --global alias.st  "status --short --branch"
git config --global alias.lg  "log --oneline --graph --decorate --all"
git config --global alias.last "log -1 --stat"
```

### 本仓库的自检

```bash
bash common/verify_expected.sh    # 期望输出契约（两人都跑）
bash tools/check_examples.sh      # 指导书两个示例能否编译
bash tools/check_laneA.sh         # A 线全链路
bash tools/check_laneB.sh         # B 线全链路
bash tools/check_mlir.sh          # MLIR（需先装 mlir-21-tools）
```

### 单条验证（不想跑整个脚本时）

```bash
# 验证自己的程序对某一个用例是否正确
你的程序 < common/testdata/case1.in | diff - common/expected/case1.out && echo PASS

# 看期望文件里有没有被转坏的 \r（每行应以 $ 结尾）
cat -A common/expected/case1.out | head -3
```

---

## 第 5 章 · 出问题时的自救

### 5.1 按现象查

| 现象 | 最可能的原因 | 去做 |
|---|---|---|
| `bash: ./tools/xxx.sh: /bin/bash^M: bad interpreter` | 脚本被转成了 CRLF | [`管理员手册.md`](管理员手册.md) 第 7.1 节 |
| `diff` 明明程序对却全部 FAIL | 期望输出被转成 CRLF | [`管理员手册.md`](管理员手册.md) 第 7.2 节 |
| `git status` 里中文文件名是 `\345\210\206...` | 没设 `core.quotepath` | 第 1.2 节 |
| `cannot find crt0.o` / `-lc` / `-lgloss` | B：没有 libc，必须 `-nostdlib` | 第 2.2 节 |
| B：汇编链接都对，qemu 退出码恒为 1、无输出 | 入口点被链接器换成 `main`，`_start` 被跳过 | [`plan-B.md`](plan-B.md) 第四节 |
| B：`ilp32d/lp64d ABI can't be used when d extension isn't supported` | 手写了 `.attribute arch` 但没含 `d` 扩展 | 删掉 `.attribute arch` 那行 |
| B：`relocation truncated to fit: R_RISCV_HI20` | 用了 `-Ttext=0x90000000` 但没加 `-mcmodel=medany` | 补上 `-mcmodel=medany` |
| A：`call to undeclared function 'getint'` | clang 21 不允许隐式函数声明 | 源程序顶部补原型（`common/sysy_main.c` 已有） |
| A：`x86-64 is not a recognized processor` | 先生成了 x86 版 IR 再交给 `llc -mtriple=riscv64` | clang 那一步就带 `--target=riscv64-unknown-elf` |
| CI 红但本地绿 | 环境版本差异 / CI 上缺课程运行库 | [`管理员手册.md`](管理员手册.md) 第 5.3 节 |
| `mlir-opt: unknown pass` | MLIR 版本 pass 名不同 | `mlir-opt --help \| grep -i 关键词` |

### 5.2 拿不准的时候，这样求助

**不要去群里问"我的代码跑不起来"。** 把下面五样东西一次说清，对方不用猜：

```
1. 我想做什么：
2. 我敲的命令（完整复制）：
3. 完整报错（从第一行到最后一行复制）：
4. 我已经试过什么：
5. 相关文件在哪、哪一行：
```

**如果是仓库设置或 CI 的问题** → 找管理员（A），或者直接在 GitHub 开 Issue。
**如果是自己那条线的技术问题** → 先翻 [`plan-A.md`](plan-A.md) / [`plan-B.md`](plan-B.md) 的对应章节，
两份方案里已经写了每个环节该怎么做、以及三个实测踩过的坑。

### 5.3 记住一件事：简单的事不用商量

本组的约定是：**简单的事各自独立做一遍，不对答案。**
看指导书的阶乘/斐波那契示例、跑 MLIR 的降级，都属于这一类——
你自己跑通了就是你的成果，不用等对方、也不用和对方比对。

真正需要走流程的只有一件事：**想改 `common/` 里的公共文件，先开 Issue。**
