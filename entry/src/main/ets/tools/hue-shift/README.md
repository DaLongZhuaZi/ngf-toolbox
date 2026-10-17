# hue-shift（色相微调）

输入色 + 色相偏移角度 + 明度偏移 → 结果色（hex 与 HSL 报告）。
薄封装 ColorConvert 的 rotateHue/adjustLightness（主题门禁同源）。

- 演示的 NGF 层：utils、uiTheme
- 纯逻辑：HueShiftLogic.ets（HueShiftTest.test.ets 5 条，手算锚点）
- 页面：HueShiftPage.ets
- 设计场景：品牌色定稿后的同色系变体（±15° 微调）。
