# json-toml（TOML 解析）

TOML 转 JSON 单向。支持：基础表 [section]、子表 [a.b]、键值对
（字符串/整数/浮点/布尔/单行数组）、注释（含行内，引号外）、点键 a.b = 1。
不支持：多行字符串（三引号明确报错）、内联表、日期时间类型。

- 演示的 NGF 层：utils、data
- 纯逻辑：JsonToml.ets（JsonTomlTest.test.ets 9 条）
- 页面：JsonTomlPage.ets
- 实现注记：逐行状态机；常量全部 String.fromCharCode（防写入器转义坑）。
