# url-parser（URL 解析器）

手写解析（不依赖设备 URL API）：scheme/userinfo/host/port/path/query/fragment 七段拆解
+ query 逐参数（+ 是空格、%2B 是字面加号）。端口默认值按 scheme 补。

- 演示的 NGF 层：utils、contentWorkflow
- 纯逻辑：`UrlParser.ets`（`UrlParserTest.test.ets` 9 条）
- 页面：`UrlParserPage.ets`
- 不做 IDN 转码、不校验 host 合法性（只做结构拆分）、不支持相对 URL。
