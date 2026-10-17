# percent-calc（百分比计算）

五个方向独立函数：占比 / 求部分 / 增长率 / 求总数 / 加减百分比。
除零（分母）明确报错——「200 加 50% = 300 但 300 减 50% = 150」的不对称性
是这类计算最常踩的坑，页面用说明承担。

- 演示的 NGF 层：utils
- 纯逻辑：`PercentCalc.ets`（`PercentCalcTest.test.ets` 8 条，方向混淆反例）
- 页面：`PercentCalcPage.ets`；文案：`PercentCalcMessages.ets`
