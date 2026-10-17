# bit-ops（位运算器）

32 位无符号整数的 AND/OR/XOR/NOT 与移位可视化：输入十进制或 0x 十六进制，
输出 32 个位格子（bit31 在左）+ 十六/十进制结果。页面可点击位格子翻转任意位。

- 演示的 NGF 层：utils
- 纯逻辑：`BitOps.ets`（`BitOpsTest.test.ets` 12 条，覆盖 0xFFFFFFFF/1<<31 等有符号溢出点）
- 页面：`BitOpsPage.ets`；文案：`BitOpsMessages.ets`
- 实现注记：位运算全部用「数学等价」表达（除二取整/负则加 2^32）——
  hypium 对超 31 位值的 >>> << 不可靠（checksum 第 81 轮同款教训）
