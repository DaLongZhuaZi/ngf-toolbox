# tz-meeting（时区会议时间）

输入基准时区时刻 → 八城市对照（北京/东京/新加坡/伦敦/巴黎/纽约/旧金山/悉尼），
并标记「8:00-22:00 当地工作时段」合理性。薄封装时间戳的 formatWithOffset。

- 演示的 NGF 层：utils、platform_ohos
- 纯逻辑：TzLogic.ets（TzMeetingTest.test.ets 5 条，手算锚点）
- 页面：TzPage.ets
- 固定偏移不含夏令时（limitation 写明）；基准时区可切换。
