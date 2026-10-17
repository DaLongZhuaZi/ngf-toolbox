# code-minify（代码压缩预览）

文本级压缩：剥离双斜线行注释与块注释（字符串字面量保护）、
连续空白压单空格。输出压缩后文本 + 原始/压缩后字符数对比。

- 演示的 NGF 层：utils
- 纯逻辑：CodeMinifyLogic.ets（CodeMinifyTest.test.ets 7 条）
- 页面：CodeMinifyPage.ets
- 不做 AST 级压缩（不改标识符与语义）；未闭合块注释报错。
