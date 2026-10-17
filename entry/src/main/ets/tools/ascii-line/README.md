# ascii-line（ASCII 分隔线）

IDE 注释用的分隔线/横幅/文本框生成：5 种填充字符（=*/#~-）、
3 种形态（line/banner/box）、3 种注释前缀（// # --）、宽度 10-120。

- 演示的 NGF 层：utils
- 纯逻辑：AsciiLineLogic.ets（AsciiLineTest.test.ets 7 条，逐字符断言）
- 页面：AsciiLinePage.ets
- 中文按 1 字符宽计算（CJK 双宽对齐是已知偏差，limitation 会写明）。
