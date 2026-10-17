# http-headers（HTTP 头速查）

本地表 24 个高频请求/响应头（方向标注：请求/响应/双向），
每条「含义 + 示例值」。关键词模糊匹配（头名+中文含义，大小写不敏感）+ 方向过滤胶囊。

- 演示的 NGF 层：utils、contentWorkflow
- 纯逻辑：`HttpHeaders.ets`（`HttpHeadersTest.test.ets` 8 条）
- 页面：`HttpHeadersPage.ets`
- 不收录全量 RFC 头，也不做头值语法校验。
