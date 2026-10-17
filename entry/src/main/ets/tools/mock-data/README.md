# mock-data（假数据生成）

中文姓名（姓氏表×名字表）、手机号（真实号段前缀+随机尾）、
邮箱（字母用户名+example.com 保留域）。随机源可注入（测试确定性）。
全部是假数据，不含真实个人信息。

- 演示的 NGF 层：utils
- 纯逻辑：MockDataLogic.ets（MockDataTest.test.ets 5 条，格式断言）
- 页面：MockDataPage.ets
- 上限 200 条；不生成身份证/地址等敏感类型。
