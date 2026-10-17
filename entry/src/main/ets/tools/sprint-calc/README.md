# sprint-calc（迭代计算）

工作日加减（周末跳过）：ISO 日期 + 工作日数（可负）→ 结果日期 +
星期 + 自然日数。UTC 日期算术（避免时区偏移）。上限 3650 天。

- 演示的 NGF 层：utils
- 纯逻辑：SprintLogic.ets（SprintCalcTest.test.ets 6 条，手算锚点）
- 页面：SprintPage.ets
- 不含节假日表（法定假日是地区数据，limitation 会写明）。
