// ============================================================================
// MLIR 进阶任务：VecAdd 逐层 lowering 的起点
//
// 两人分工（各跑一半，中间只交接一次产物）：
//   A 跑 L1 -> L2 -> L3   （高层方言 降到 结构化控制流）
//   B 跑 L3 -> L4 -> L5   （继续降到 LLVM 方言，并在 L5 与 LLVM IR 汇合）
//   交接物：advanced-mlir/logs/l3.mlir（A 生成，B 拿去当输入，之后 A 不再改它）
//
// ---------------------------------------------------------------------------
// 为什么这里用 linalg.add 而不是 arith.addf：
//   arith.addf 是"元素级算子"，张量级别上它只是个手写循环；
//   linalg.add 是"具名算子"，携带完整的算子语义（输入/输出/形状），
//   只有具名算子才能被 --linalg-generalize-named-ops 泛化成 linalg.generic，
//   进而被 --convert-linalg-to-loops 降成显式循环。
//   所以起点必须是 linalg.add，这是整条 lowering 链能启动的前提。
// ---------------------------------------------------------------------------

// 第一段：MLIR 源程序（下面 vecadd-parse-begin / end 之间的内容就是完整的 mlir 源）
// vecadd-parse-begin
module {
  func.func @vecadd(%a: tensor<16xf32>, %b: tensor<16xf32>) -> tensor<16xf32> {
    %0 = linalg.add ins(%a, %b : tensor<16xf32>, tensor<16xf32>)
                    outs(%a : tensor<16xf32>) -> tensor<16xf32>
    return %0 : tensor<16xf32>
  }
}
// vecadd-parse-end

// ---------------------------------------------------------------------------
// 完整命令序列（各层的产物都存到 advanced-mlir/logs/，报告里贴片段）
//
//   【A 负责】
//   # L1: 把 linalg 具名算子泛化成 linalg.generic
//   mlir-opt advanced-mlir/vecadd/vecadd.mlir \
//       --pass-pipeline='builtin.module(func.func(linalg-generalize-named-ops))' \
//       -o advanced-mlir/logs/l1.mlir
//
//   # L2: linalg.generic -> 显式循环（张量语义开始消失，出现下标和循环边界）
//   mlir-opt advanced-mlir/logs/l1.mlir --convert-linalg-to-loops \
//       -o advanced-mlir/logs/l2.mlir
//
//   # L3: scf 结构化控制流 -> cf 底层控制流（变成基本块 + 条件跳转）
//   #     这一层是交接点：产出 l3.mlir，交给 B，之后 A 不再改动它
//   mlir-opt advanced-mlir/logs/l2.mlir --convert-scf-to-cf \
//       -o advanced-mlir/logs/l3.mlir
//
//   【B 负责】
//   # L3.5: 张量要变成内存。tensor 是值语义（没有地址），memref 是内存语义（有地址）。
//   #       这一步必须先做 bufferization，否则 --convert-to-llvm 会因为 tensor 没法转内存而报错。
//   mlir-opt advanced-mlir/logs/l3.mlir \
//       --one-shot-bufferize='bufferize-function-boundaries' \
//       --buffer-deallocation-pipeline \
//       -o advanced-mlir/logs/l3_5.mlir
//
//   # L4: 全部降到 LLVM 方言（memref 缓冲化 + 标准方言转 LLVM）
//   mlir-opt advanced-mlir/logs/l3_5.mlir --convert-to-llvm \
//       -o advanced-mlir/logs/l4.mlir
//
//   # L5: LLVM 方言 -> LLVM IR 文本（在这里与 A 写的第 2 章 LLVM IR 汇合）
//   mlir-translate --mlir-to-llvmir advanced-mlir/logs/l4.mlir \
//       -o advanced-mlir/logs/l5.ll
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// 每一层要回答的三个问题（写报告第 4 章的统一格式，A/B 各答自己那几层）
//   (a) 这一层还能看见"两个向量相加"这个语义吗？
//   (b) 这一层新出现了什么概念？（循环？下标？指针？基本块？函数？）
//   (c) 上一层的哪些信息在这一层被永久丢掉了？
// ----------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// 备用起点：如果 linalg.add 在你装的 MLIR 版本里叫法不同（不同版本方言会改名），
// 可以退化成下面这份"显式仿射循环"版本，它有同样的"逐层降低"观察价值，
// 但从 L2 起步（不经过 linalg）。用之前先把上面第一段注释掉。
// ----------------------------------------------------------------------------
// module {
//   func.func @vecadd(%a: memref<16xf32>, %b: memref<16xf32>, %c: memref<16xf32>) {
//     affine.for %i = 0 to 16 {
//       %0 = affine.load %a[%i] : memref<16xf32>
//       %1 = affine.load %b[%i] : memref<16xf32>
//       %2 = arith.addf %0, %1 : f32
//       affine.store %2, %c[%i] : memref<16xf32>
//     }
//     return
//   }
// }
