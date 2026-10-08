# A 的工作方案（LLVM / clang 这条线）

> 这份只管 A 自己干什么，你自己看完就能开工，不需要和 B 商量。
> B 的方案在 `plan-B.md` 里，你不用去看。

---

## 一、你负责什么

题目一共四块内容，你负责前两块：

1. **了解编译器工作过程**——预处理、编译、汇编、链接，各自到底干了什么。
2. **熟悉 LLVM IR 中间语言**——自己写一份 `.ll` 文件，和源程序等价，能跑出一样的结果。

B 负责第三块（汇编语言）。**你一个字都不用写汇编**。

你干活的地方固定是这几个目录：

```
A-llvm/         你自己的工作目录，B 不会动
doc/report.md   你只写第 1 章和第 2 章，以及第 5 章结论里标了 "by A" 的那一段
tools/          自检脚本，只读
```

---

## 二、你要交的东西

| 交付物 | 放在哪 | 验收标准 |
|---|---|---|
| 手写的 LLVM IR 程序 | `A-llvm/main.ll` | 能链接运行库跑起来，两个测试用例都和期望输出逐字节一样 |
| 各阶段的产物 | `A-llvm/gen/` | `.i` `.ll` `.bc` `.s` `.o` 都在，能一条命令重新生成 |
| 观察记录 | `A-llvm/analysis/` | token 列表、AST、pass 日志、反汇编、符号表 |
| 一键复现脚本 | `A-llvm/build.sh` | 换台机器跑一遍也能出同样结果 |
| 优化对比 | `A-llvm/analysis/opt_compare.txt` | `-O0/-O1/-O2/-O3` 的文件大小、运行时间、IR 行数 |
| 报告第 1、2 章 | `doc/report.md` | 用自己跑出来的产物说话，不要抄指导书 |
| 原始笔记 | `A-llvm/A_notes.md` | 随手记，不用写好看，是写报告的素材 |

期望输出我这边已经实测冻结好了，在 `common/expected/case1.out` 和 `case2.out`。
你可以随时自己验一遍：

```bash
bash common/verify_expected.sh      # 应该打印 case1 PASS / case2 PASS
```

---

## 三、开工前，先自己独立做这三件小事

**这三件事 B 也会自己做一遍，你们各做各的，不需要对答案。**
做完你会发现指导书里那两段示例程序到底长什么样、编译出来什么结果。

这三个程序已经放在仓库里了，不用自己敲：

```
common/examples/fact.c        阶乘（指导书 1.3 节的"阶乘"示例）
common/examples/fib.c         斐波那契数列（指导书 1.3 节的第二个示例）
common/sysy_main.c            你们俩的主要测试程序（覆盖的语言特性最多）
```

### 小事 1：把阶乘和斐波那契各编译一遍，看四个阶段的产物

```bash
mkdir -p A-llvm/examples

# 阶乘
clang -E common/examples/fact.c -o A-llvm/examples/fact.i
clang -S -emit-llvm -O0 common/examples/fact.c -o A-llvm/examples/fact.ll
clang -S -O0 common/examples/fact.c -o A-llvm/examples/fact.s
clang -c -O0 common/examples/fact.c -o A-llvm/examples/fact.o

# 斐波那契
clang -E common/examples/fib.c -o A-llvm/examples/fib.i
clang -S -emit-llvm -O0 common/examples/fib.c -o A-llvm/examples/fib.ll
clang -S -O0 common/examples/fib.c -o A-llvm/examples/fib.s
clang -c -O0 common/examples/fib.c -o A-llvm/examples/fib.o
```

看的时候留意这几件事（都是报告里的素材）：

- 阶乘里那个 `while (i <= n)` 循环，在 `.ll` 里变成了几个**基本块**？条件判断用的是什么指令？
- 斐波那契里 `t = b; b = a + b; a = t;` 这种"借一个临时变量交换"的写法，在 IR 里是不是真的产生了临时变量？开了 `-O2` 之后还在不在？
- 两个程序里 `putint` 的调用，参数是怎么传的？

（参考：实测阶乘的 `.ll` 是 61 行，斐波那契是 74 行。斐波那契多出来的十几行，
大部分就是那个 `t` 变量带来的 `alloca` + `load` + `store`。）

### 小事 2：手动把指导书里那段阶乘 IR 跑一遍

指导书 3.2 节贴了一段阶乘的 LLVM IR。**别直接抄**，照着自己机器上的 `fact.ll` 对照着看，
找出指导书那段和实际生成的有哪些不一样。你大概会立刻发现两个点：

- 指导书用的是老式指针写法 `i32*`，你机器上 clang 21 生成的是 `ptr`（不透明指针）。
- 指导书里能直接写 `%5 = call i32 (i8*, ...) @__isoc99_scanf(...)`，你这边要先用 `-Wno-implicit-function-declaration` 或者干脆改写成 SysY 的 `getint()`。

**这两条已经确认过了**（详见 `分工方案.md` 第 6 节开头），你直接照着写就行，不用再去试错。

### 小事 3：看一眼汇编和反汇编的对应关系（只看不写）

```bash
objdump -d A-llvm/examples/fact.o | head -40
nm A-llvm/examples/fact.o
```

这一步是为了第 1 章"汇编器做了什么"那节。**你不需要会写汇编**，
只要说清楚"汇编里的 `add` 指令变成了机器码里哪几个字节""为什么 `.o` 文件里的函数地址还是 0 或者很小的偏移"就够了。

> 这三件小事大概 1 小时。做完你就有了写报告第 1 章的全部素材。
> 如果哪一步报错了，看 `tools/check_laneA.sh` 的输出，那个脚本会把每一步都跑一遍并打印结果：

```bash
bash tools/check_laneA.sh
```

它最后两行应该是 `case1 PASS` 和 `case2 PASS`。如果不对，先把这个脚本跑通再往下做。

---

## 四、你的主线任务（按顺序做，每步都能独立验证）

### 第 1 步：把主程序的四个阶段全跑一遍，产物留档

```bash
mkdir -p A-llvm/gen A-llvm/analysis

# 1. 预处理
clang -E common/sysy_main.c -o A-llvm/gen/main.i
clang -E -P common/sysy_main.c -o A-llvm/gen/main.p.i     # 去掉行号，方便对比
wc -l common/sysy_main.c A-llvm/gen/main.i                # 实测 155 行 -> 975 行

# 2. 词法分析、语法分析
clang -E -Xclang -dump-tokens common/sysy_main.c > A-llvm/analysis/tokens.txt 2>&1
clang -E -Xclang -ast-dump   common/sysy_main.c > A-llvm/analysis/ast.txt    2>&1

# 3. 中间代码
clang -S -emit-llvm -O0 common/sysy_main.c -o A-llvm/gen/main_O0.ll
clang -S -emit-llvm -O2 common/sysy_main.c -o A-llvm/gen/main_O2.ll
clang -c -emit-llvm -O0 common/sysy_main.c -o A-llvm/gen/main.bc

# 4. 优化 pass 前后
llc -print-before-all -print-after-all A-llvm/gen/main.bc > A-llvm/analysis/passes.log 2>&1
opt -passes='mem2reg,instcombine,simplifycfg' -S A-llvm/gen/main_O0.ll -o A-llvm/gen/main_opt.ll

# 5. 代码生成、反汇编、符号表
llc A-llvm/gen/main.bc -o A-llvm/gen/main_from_llc.s
clang -O0 -c -o A-llvm/gen/main.o A-llvm/gen/main_from_llc.s
objdump -d A-llvm/gen/main.o > A-llvm/analysis/anti_obj.S
nm A-llvm/gen/main.o         > A-llvm/analysis/nm_obj.txt
```

**做完这步要能回答**：预处理器把 155 行的文件变成 975 行，多出来的都是什么？

### 第 2 步：手写 `A-llvm/main.ll`

这是你这份工作里**最花时间、也最值钱**的一步。要求：

- 不许用 `clang -emit-llvm` 生成，**自己一行一行写**；
- 必须用 `ptr` 这种新式不透明指针（`load i32, ptr %p` 这样写），不要抄指导书的 `i32*`；
- 必须包含：全局变量、全局常量、全局数组，`if/else`，`while`，`for` 嵌套循环，`break`、`continue`，
  多参数函数，递归函数，数组当参数，浮点运算和强制类型转换；
- 每个基本块要以终结指令（`br`/`ret`）结尾。

写的时候可以拿 `A-llvm/gen/main_O0.ll` 当参照物 —— **允许看，但不要整段复制**，
报告里要说明哪些地方是自己想出来的、哪些地方参考了编译器输出。这本身就是第 2 章的对比素材。

写完自检：

```bash
llvm-as A-llvm/main.ll -o /dev/null      # 没报错说明语法合法
```

再跑起来（如果还没拿到课程提供的 `libsysy_x86.a`，用桩函数顶上）：

```bash
mkdir -p A-llvm/gen
cat > A-llvm/gen/stub.c <<'EOF'
#include <stdio.h>
int  getint(void){ int x; if (scanf("%d",&x)!=1) return 0; return x; }
void putint(int x){ printf("%d", x); }
void putch(int c){ putchar(c); }
EOF

clang -O0 -o A-llvm/gen/main_x86 A-llvm/main.ll A-llvm/gen/stub.c
for c in case1 case2; do
  ./A-llvm/gen/main_x86 < common/testdata/$c.in | diff - common/expected/$c.out \
    && echo "$c PASS"
done
```

拿到课程运行库之后换成正式命令（两个都要验一遍）：

```bash
clang -O0 -o A-llvm/gen/main_x86 A-llvm/main.ll -L A-llvm/libsysy -lsysy_x86
lli -load=./A-llvm/libsysy/sylib.so A-llvm/main.ll        # JIT 方式，可选
```

### 第 3 步：编译选项对比（这步是加分项，但很容易做）

```bash
for O in 0 1 2 3; do
  clang -O$O common/sysy_main.c -o A-llvm/gen/o$O
  printf "O%s size=%s bytes\n" $O "$(stat -c%s A-llvm/gen/o$O)"
  /usr/bin/time -f "   O$O time=%e s" ./A-llvm/gen/o$O < common/testdata/case1.in > /dev/null
done | tee A-llvm/analysis/opt_compare.txt
```

顺便把 `-O0` 和 `-O2` 的 IR 行数也记下来（实测 433 行 vs 430 行，差别不大——
**这件事本身就值得在报告里写一句**：为什么优化等级上去了，IR 行数几乎没变？

### 第 4 步：写 `A-llvm/build.sh`

把上面所有命令按顺序写进一个脚本，加上 `set -e`，让任何人跑一遍就能重新生成全部产物。
这是给助教看的"可复现性"证据。

### 第 5 步：写报告第 1、2 章

直接改 `doc/report.md`，**只填第 1 章、第 2 章，和第 5 章里 `<!-- by A -->` 那一段**。
小节的标题和编号已经定好了，**不要改标题**（B 也在同一个文件里写，改标题会撞车）。

第 5 章你只写 `<!-- by A -->` 到 `<!-- by B -->` 之间那一段，B 写他自己那段，互不覆盖。

---

## 五、报告怎么写才不像抄的

指导书已经把流程讲了一遍，你再抄一遍没有分。能拿分的是**你自己测出来的数**和**你自己发现的差异**。建议每节都按这个套路写：

> 我执行了什么命令 → 得到什么输出（贴片段）→ 这个输出说明编译器在这一步做了什么 → 和我的预期有没有不一样

几个现成的、别人大概率写不出来的点：

1. 预处理后文件从 155 行变 975 行，多出来的绝大部分是 `#include <stdio.h>` 展开的，
   而**你真正用到的只有 `getint/putint/putch` 三个函数**——顺手提一句"为什么 SysY 不给这几个函数头文件"。
2. clang 21 报"隐式函数声明"是**错误**不是警告（C99 之后的行为），
   这正好说明**语义分析阶段要做符号表查找和类型检查**。
3. 你机器上生成的 IR 里 `i32*` 出现 **0** 次，`ptr` 出现 **144** 次——
   这是 Opaque Pointer 特性，写进第 2 章比抄指导书 3.4 节有说服力得多。
4. `-O0` 和 `-O2` 的 IR 行数只差 3 行。为什么？因为 `-O0` 下 `alloca/load/store` 一大堆，
   `-O2` 下 `mem2reg` 把它们变成了 SSA 值，但**函数多了内联和别的变换**，总量抵消了。
   这个观察怎么写都比你直接说"优化能让代码变快"强。
5. `llc -print-before-all -print-after-all` 的日志里，找一个 pass 前后 IR 的具体变化贴出来
   （推荐看 `mem2reg`：`alloca`+`load`+`store` 变没了，直接变成 `%x = add i32 ...`）。

写得像"我做了一个实验"，而不是"我读了一本书"。

---

## 六、MLIR 进阶（1 分）：你和 B 一人跑一半

这块改成**两人协作**：把 lowering 链从中间切开，**你负责上半段（L1→L3）**，B 负责下半段（L3→L5）。
切点是 `l3.mlir`。这样你俩各自都有真东西可写，但**依然不用一起坐在电脑前**。

### 你负责的三层

| 层 | 命令 | 这一层发生了什么 |
|---|---|---|
| **L1** | `linalg-generalize-named-ops` | 把 `linalg.add` 这个具名算子泛化成 `linalg.generic`，算出循环的维度和索引映射 |
| **L2** | `convert-linalg-to-loops` | `linalg.generic` 降成显式循环，**"张量"这个概念在这里开始消失**，变成下标和步长 |
| **L3** | `convert-scf-to-cf` | 结构化控制流（`scf.for`）降成底层控制流（基本块 + 条件跳转） |

```bash
mkdir -p advanced-mlir/logs

# 先把示例里真正的 MLIR 源抽出来（文件里其余都是注释）
sed -n '/vecadd-parse-begin/,/vecadd-parse-end/p' advanced-mlir/vecadd/vecadd.mlir \
  | grep -v '^\s*//' > advanced-mlir/logs/vecadd_core.mlir

mlir-opt advanced-mlir/logs/vecadd_core.mlir \
    --pass-pipeline='builtin.module(func.func(linalg-generalize-named-ops))' \
    -o advanced-mlir/logs/l1.mlir
mlir-opt advanced-mlir/logs/l1.mlir --convert-linalg-to-loops -o advanced-mlir/logs/l2.mlir
mlir-opt advanced-mlir/logs/l2.mlir --convert-scf-to-cf     -o advanced-mlir/logs/l3.mlir
```

**注意 L1 的写法**：不能简写成 `--linalg-generalize-named-ops`，这个 pass 是函数级 pass，
在顶层直接跑会报 pass 锚点不匹配，必须写成上面那种 `--pass-pipeline` 形式。

### 你要交给 B 的东西

**`advanced-mlir/logs/l3.mlir`**——生成完就**不要再改它**，B 拿它当输入往下跑。
这就是你俩在这块上唯一的一次交接，交接完各干各的。

顺手把每一层的方言清单打出来（写报告很有用）：

```bash
for f in vecadd_core l1 l2 l3; do
  printf "%-14s " "$f"
  grep -oE '\b(linalg|tensor|memref|scf|cf|arith|func|affine|llvm)\.[a-z_]+' \
    advanced-mlir/logs/$f.mlir | cut -d. -f1 | sort -u | tr '\n' ' '
  echo
done
```

你会看到 `tensor` 在 L2 之后就基本不出现了，`linalg` 到 L3 也消失了——
**"信息在哪一层丢掉"这件事最好用这张表来说**，比空口讲"渐进式降低"有力得多。

### 每层要回答的三个问题（报告第 4 章的固定格式）

1. 这一层还能看见"两个向量相加"这个意思吗？
2. 这一层新出现了什么概念？（循环？下标？指针？基本块？）
3. 上一层的哪些信息在这一层永久丢掉了？

### 你写在报告的哪一节

报告 `doc/report.md` 第 4 章已经按 `4.1 / 4.2 / 4.3 / 4.4` 分好了：

- **4.1**（MLIR 多级方言与 LLVM IR 单层的本质区别）—— 你写
- **4.2**（L1→L3 逐层观察）—— 你写
- **4.3**（L3→L5、bufferization、与 LLVM IR 汇合）—— B 写，你别动
- **4.4**（结论）—— 你写 `<!-- by A -->` 那段，B 写 `<!-- by B -->` 那段

### 环境

**你机器上现在没有 `mlir-opt` / `mlir-translate`。** 要你自己在 WSL 里装（要输密码，我装不了）：

```bash
sudo apt update && sudo apt install -y mlir-21-tools
```

装好后先跑这个自检脚本，它会把 L1→L3 完整跑一遍并检查交接物：

```bash
bash tools/check_mlir.sh
```

> 你装的是 MLIR 21，而课程 PPT 里提到 Ascend NPU IR 基于 LLVM 15 时代的 MLIR。
> **pass 名字在不同版本之间确实改过**。如果哪条命令报 "unknown pass"，
> 用 `mlir-opt --help | grep -i <关键词>` 找当版本的名字，然后在报告里如实记一句
> "本机为 MLIR 21，pass 名与 15 版本有差异"——这本身就是有价值的观察，不算错。
>
> 实在装不上，就跳过这 1 分，**别为它耽误基础 4 分**。

---

## 七、和 B 的界线（照这个执行就不会吵架）

| 情况 | 怎么办 |
|---|---|
| 你发现 `common/` 里的源程序有问题 | **不要直接改**。在 GitHub 开一个 Issue 写上"哪里不对、建议怎么改"。因为 B 也依赖这份文件，你改了会让他白跑一遍 |
| 你想改 `common/examples/fact.c` 之类 | 同上。要么开 Issue，要么**复制一份到你自己的 `A-llvm/` 目录下改**，别动公共文件 |
| 你看不懂 B 的 `.S` 文件 | 不用看。你不需要理解汇编（第 1 章只需要说清"汇编器做了什么"） |
| B 的进度慢 | 照常提交你自己那半。报告里如实写分工比例就行，不要停下来等 |
| 你需要 B 配合 | 先去 GitHub 开 Issue。能异步说清的事不要当面说 |
| 报告格式不统一 | 已经定好了：你只用 `doc/figures/fig-A-*.png` 和"表 A-1"这种编号，B 用 `B-`。物理上不可能撞 |

**唯一必须和 B 打照面的时刻**，是开工前确认三件事（15 分钟，说清楚就散）：
①`common/` 里的三个程序都不再改；②期望输出用 `common/expected/` 里那两个文件；
③报告骨架的标题编号不动。确认完就各干各的。

---

## 八、自查清单（做完一条打个勾，不用等 B 确认）

- [ ] 阶乘、斐波那契各自跑出 `.i` `.ll` `.s` `.o`，放在 `A-llvm/examples/`
- [ ] 能说出阶乘的 `while` 循环对应 IR 里哪几个基本块
- [ ] `common/sysy_main.c` 的四个阶段产物齐全
- [ ] `main.i` 明显比源文件长（实测 155 → 975 行）
- [ ] `llvm-as A-llvm/main.ll -o /dev/null` 不报错
- [ ] 手写 `main.ll` 用 `ptr` 而不是 `i32*`
- [ ] 手写 `main.ll` 在 case1、case2 上都和期望输出一致
- [ ] `opt_compare.txt` 里有 `-O0` 到 `-O3` 的大小和时间
- [ ] `passes.log` 里能指出至少一个 pass 前后的具体差异
- [ ] `A-llvm/build.sh` 能从空目录一键重建全部产物
- [ ] 报告第 1、2 章写完，第 5 章 `<!-- by A -->` 那段写完
- [ ] MLIR：L1→L3 跑完，`advanced-mlir/logs/l3.mlir` 已生成并**通知 B**
- [ ] MLIR：每层的方言清单打出来了（看 `tensor`/`linalg` 在哪一层消失）
- [ ] MLIR：报告 4.1、4.2 写完，4.4 里的 `<!-- by A -->` 那段写完
- [ ] MLIR：如果没装成，明确记下"为什么没做"
