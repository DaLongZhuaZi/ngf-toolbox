# ua-parser（UA 解析）

启发式三维分类：浏览器（Edg/OPR/Firefox/Chrome/Safari，**顺序敏感**——
Edge 的 UA 里也含 Chrome/，必须先查 Edg/）、引擎（Blink/Gecko/WebKit）、OS（五大系统）。
无法识别返回 unknown + partial 标记——UA 可伪造，这是机制固有限制而非实现缺陷。

- 演示的 NGF 层：utils
- 纯逻辑：`UaParser.ets`（`UaParserTest.test.ets` 9 条，真实 UA 样本）
- 页面：`UaParserPage.ets`
