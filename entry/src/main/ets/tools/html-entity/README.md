# html-entity（HTML 实体编解码）

三类实体双向：命名实体（内置 39 个常用项，大小写不敏感）、十进制 `&#38;`、十六进制 `&#x26;`。
编码默认只转五个 HTML 保留字符；扩展模式把非 ASCII 编成十进制实体。解码遇到未知命名实体、
码点越界、缺分号时**报错不猜**——浏览器式宽容会把问题藏起来。

- 演示的 NGF 层：utils
- 纯逻辑：`HtmlEntity.ets`（零 import，`HtmlEntityTest.test.ets` 10 条）
- 页面：`HtmlEntityPage.ets`；文案：`HtmlEntityMessages.ets`
- 实现注记：实体表用平行数组而非 Map+IIFE（hypium 与 Node 的模块初始化时序差异，
  见第 74 轮记录）；所有字符用 fromCharCode 表达（写入器转义坑）。
