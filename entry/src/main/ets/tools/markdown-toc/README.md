# markdown-toc（Markdown 目录）

扫描一至三级标题生成缩进目录（GitHub 风格锚点：小写、空格转横线、
去标点、保留中文）。代码块围栏内的井号行跳过。

- 演示的 NGF 层：utils、contentWorkflow
- 纯逻辑：MarkdownTocLogic.ets（MarkdownTocTest.test.ets 5 条）
- 页面：MarkdownTocPage.ets
- 锚点规则与 GitHub 对齐；四级及更深标题忽略。
