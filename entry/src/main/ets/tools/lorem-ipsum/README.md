# lorem-ipsum（占位文本生成）

拉丁与中文两套词表；段落/句数可配（1..20）；**种子随机**（mulberry32）——同一种子产出
完全相同的文本，可复现也可单测。拉丁句首大写句号收尾，中文逗号分隔句号收尾。

- 演示的 NGF 层：utils、contentWorkflow
- 纯逻辑：`LoremIpsum.ets`（零 import，`LoremIpsumTest.test.ets` 8 条，含确定性断言）
- 页面：`LoremIpsumPage.ets`；文案：`LoremIpsumMessages.ets`
