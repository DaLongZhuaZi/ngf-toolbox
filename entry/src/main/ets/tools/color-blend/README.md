# color-blend（两色混合）

RGB 线性插值：两色 + 步数（2-12）→ 渐变色带（含 B 占比标注）。
颜色解析复用 ColorConvert（同一套入口）。

- 演示的 NGF 层：utils、uiTheme
- 纯逻辑：ColorBlendLogic.ets（ColorBlendTest.test.ets 5 条，黑/白/红/蓝手算锚点）
- 页面：ColorBlendPage.ets
