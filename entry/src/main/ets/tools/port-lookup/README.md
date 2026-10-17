# port-lookup（端口速查）

本地表 30 个高频端口（端口号唯一），每条「服务名 + 中文用途」。
查询支持数字前缀（80 匹配 80/8080/8443）、服务名与中文用途模糊。

- 演示的 NGF 层：utils、network
- 纯逻辑：`PortLookup.ets`（`PortLookupTest.test.ets` 7 条）
- 页面：`PortLookupPage.ets`
- 与 port-tester 互补：那是连通测试，这是用途查询。
