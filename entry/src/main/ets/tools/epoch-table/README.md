# epoch-table（Epoch 对照表）

给定毫秒值输出常用粒度对照：秒（10 位）/毫秒（13 位）/微秒/天/小时。
**确定性设计**：ms 由调用方传入，本模块不做时钟读取——可复现可单测。
薄封装时间戳工具的换算函数（formatWithOffset 等）。

- 演示的 NGF 层：utils、data
- 纯逻辑：`EpochTable.ets`（`EpochTableTest.test.ets` 6 条，含 round-trip）
- 页面：`EpochTablePage.ets`
