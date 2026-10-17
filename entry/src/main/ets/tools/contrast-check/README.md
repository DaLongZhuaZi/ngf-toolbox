# contrast-check（WCAG 对比度检查）

双色的 WCAG 2.1 对比度与等级判定（AA/AA Large/AAA/Fail，区分普通与大文本），
并给出「这块背景上黑字还是白字更可读」的建议。**复用 color-convert 的
relativeLuminance/contrastRatio**——那是对的主题门禁的同一份实现，不复制。

- 演示的 NGF 层：utils、uiTheme
- 纯逻辑：`ContrastCheck.ets`（`ContrastCheckTest.test.ets` 8 条，WCAG 已知值）
- 页面：`ContrastCheckPage.ets`；文案：`ContrastCheckMessages.ets`
