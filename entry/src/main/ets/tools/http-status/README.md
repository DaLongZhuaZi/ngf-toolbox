# http-status（HTTP 状态码速查）

本地表 23 条高频状态码（五大分类），每条「含义 + 常见原因」两句。
查询支持数字精确/前缀（40 匹配 400-409）与文本模糊（name + 中文含义）。

- 演示的 NGF 层：utils、contentWorkflow
- 纯逻辑：`HttpStatus.ets`（`HttpStatusTest.test.ets` 8 条，表内容事实断言）
- 页面：`HttpStatusPage.ets`；文案：`HttpStatusMessages.ets`
- 不收录全量 RFC 60+ 状态码——工具书要短，不是要全。
