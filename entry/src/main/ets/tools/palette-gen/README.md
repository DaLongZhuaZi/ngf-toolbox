# palette-gen（色板生成）

**薄封装 ColorConvert**：harmony（互补/邻近/三角/四角）+ 每色 5 档明暗阶梯
（lightnessScale）。输入支持 #FFF / #0962F2 / rgb() 等全部 parseColor 口径。

- 演示的 NGF 层：utils、uiTheme
- 纯逻辑：`PaletteGen.ets`（99 行薄封装；`PaletteGenTest.test.ets` 8 条结构断言）
- 页面：`PaletteGenPage.ets`；文案：`PaletteGenMessages.ets`
