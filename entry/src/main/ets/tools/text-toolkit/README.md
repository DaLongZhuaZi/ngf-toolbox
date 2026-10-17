# text-toolkit（文本行工具）

多行文本的去重（保留首次出现）/ 排序（原序、字典序、长度升降、反转）/ 统计
（行数、字符、词数、CRLF/LF 行尾计数）。trim 与剔除空行可独立开关；统计基于剔除后的行。

- 演示的 NGF 层：utils、contentWorkflow
- 纯逻辑：`TextToolkit.ets`（零 import，`TextToolkitTest.test.ets` 9 条）
- 页面：`TextToolkitPage.ets`；文案：`TextToolkitMessages.ets`
