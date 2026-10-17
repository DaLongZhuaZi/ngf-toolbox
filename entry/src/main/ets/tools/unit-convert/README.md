# unit-convert（单位换算）

四类比例换算（数据量 1024 进制 / 长度 / 时间 / 重量）+ 温度仿射换算（摄氏/华氏/开尔文，
拦绝对零度以下）。系数表到基准单位，换算 = 值 × 源系数 ÷ 目标系数。

- 演示的 NGF 层：utils
- 纯逻辑：`UnitConvert.ets`（`UnitConvertTest.test.ets` 9 条，手算基准 + round-trip）
- 页面：`UnitConvertPage.ets`；文案：`UnitConvertMessages.ets`
- 不支持：复合单位（m/s）、公制吨位变体、历史单位
