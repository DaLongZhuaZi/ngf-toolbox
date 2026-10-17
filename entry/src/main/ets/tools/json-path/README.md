# json-path（JSON 点路径取值）

点路径语法：a.b.c、a.list[0].name、根数组 [0].id。
**手写解析器**（不用 eval——路径来自用户输入，eval 是注入面）。
不支持通配符、过滤器、负数下标。

- 演示的 NGF 层：utils、contentWorkflow
- 纯逻辑：`JsonPath.ets`（`JsonPathTest.test.ets` 9 条）
- 页面：`JsonPathPage.ets`
- 实现注记：正则字面量用 isAllDigits 手写循环替代（写入器转义坑）；
  「index 段之后的 .」不能当连续点报错（第一版的 bug）。
