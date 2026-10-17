# float-bits（IEEE-754 位分解）

单精度（32 位）/双精度（64 位）的符号/指数/尾数分解，输出十六进制位型与
**五分类**（规格化/非规格化/零/无穷/NaN）。用 ArrayBuffer 类型化数组读写，
NaN 与 Infinity 显式构造位型（f32 写 NaN 再读 u32 在部分运行器返回 0）。

- 演示的 NGF 层：utils、data
- 纯逻辑：`FloatBits.ets`（`FloatBitsTest.test.ets` 10 条，标准位型断言）
- 页面：`FloatBitsPage.ets`；文案：`FloatBitsMessages.ets`
- 输入语义：NaN/Infinity/-Infinity 字面量合法（看它们的位型）；其它解析失败报错
