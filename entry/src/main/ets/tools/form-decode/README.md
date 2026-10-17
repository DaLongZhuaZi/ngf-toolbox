# form-decode（表单编码解析）

application/x-www-form-urlencoded 语义解析：逐参数拆解 + 原始/解码双视图 +
**重复键保留多条**（多选框语义）+ 唯一键统计。解码复用 url-codec（+ 是空格的表单口径）。

- 演示的 NGF 层：utils、contentWorkflow
- 纯逻辑：`FormDecode.ets`（`FormDecodeTest.test.ets` 8 条）
- 页面：`FormDecodePage.ets`
- 与 url-codec 分工：那是整串编解码，这是表单体语义（? 开头报错提示）。
