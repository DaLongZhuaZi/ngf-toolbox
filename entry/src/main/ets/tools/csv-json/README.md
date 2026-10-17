# csv-json（CSV 与 JSON 互转）

CSV 按 RFC 4180 解析（首行表头、引号字段内逗号/换行/双引号转义），
值类型推断只发生在 CSV→JSON 方向（15 位以上数字保留字符串防丢精度），
JSON→CSV 全部转字符串并按需加引号。键集合以首行为准，缺键报错。

- 演示的 NGF 层：utils、contentWorkflow
- 纯逻辑：`CsvJson.ets`（零 import，`CsvJsonTest.test.ets` 8 条，含 round-trip）
- 页面：`CsvJsonPage.ets`；文案：`CsvJsonMessages.ets`
