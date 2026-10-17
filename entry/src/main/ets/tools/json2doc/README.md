# json2doc（JSON 转接口文档）

JSON 示例 → Markdown 字段表（路径 | 类型 | 说明占位）。
对象键点分路径、数组取首元素下钻（路径带 [0]）、深度上限 4 层、
对象根不产生根行（从字段开始）。

- 演示的 NGF 层：utils、contentWorkflow
- 纯逻辑：Json2DocLogic.ets（Json2DocTest.test.ets 6 条，表格结构断言）
- 页面：Json2DocPage.ets
- 说明列留空由用户补充——工具不猜测字段含义。
