# regex-replace（正则替换预览）

正则替换的预览态：替换后全文 + 每次匹配的原文与位置清单。
支持 $1-$9 捕获组引用、g/i/m 标志（其余剥掉）、空匹配防死循环。

- 演示的 NGF 层：utils、contentWorkflow
- 纯逻辑：RegexReplaceLogic.ets（RegexReplaceTest.test.ets 7 条）
- 页面：RegexReplacePage.ets
- 实现注记：测试里 \w 必须写成源码双反斜杠（JS 字符串转义——单反斜杠
  会被剥类型器保留为字面 w）。
