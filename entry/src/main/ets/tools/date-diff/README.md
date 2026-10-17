# date-diff（日期差计算）

两个 ISO 日期之间：自然日差（含方向）、工作日数（跳过周末）、周数。
UTC 日期算术；start 晚于 end 结果为负。

- 演示的 NGF 层：utils
- 纯逻辑：DateDiffLogic.ets（DateDiffTest.test.ets 6 条，手算锚点）
- 页面：DateDiffPage.ets
- 与 sprint-calc 配对：那是由日数推日期，这是由两日期算差值。
