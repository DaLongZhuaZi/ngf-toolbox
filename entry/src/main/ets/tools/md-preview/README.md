# md-preview（Markdown 预览）

行级渲染模型：标题（#/##/###）、段落聚合、有序/无序列表、引用、代码块、水平线；
行内支持粗体/斜体/行内代码。输出「渲染节点列表」由页面转成 ArkUI 组件——
样式走主题 Token、字号走 scaled()，关怀模式天然生效，而不是拼 HTML。

- 演示的 NGF 层：utils、contentWorkflow
- 纯逻辑：`MdPreview.ets`（零 import，`MdPreviewTest.test.ets` 9 条）
- 页面：`MdPreviewPage.ets`；文案：`MdPreviewMessages.ets`
- 不支持：表格、嵌套列表、图片与链接跳转（只显示文本）、四级以上标题
