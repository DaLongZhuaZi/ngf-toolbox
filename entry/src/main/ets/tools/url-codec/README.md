# url-codec（URL 编解码）

把「整串编解码」与「query 逐参数拆解」分开：整串走 encodeURIComponent/decodeURIComponent 口径，
query 按 & 与「段内第一个 =」切分，每个参数同时给出表单口径（+ 为空格）与字面口径（+ 保留）两版解码值——
不替用户猜 + 的语义。畸形 % 序列报错并指明第几个参数。

- 演示的 NGF 层：utils（纯逻辑）、contentWorkflow（解析-展示流）
- 纯逻辑：`UrlCodec.ets`（零 import，`UrlCodecTest.test.ets` 10 条）
- 文案映射：`UrlCodecMessages.ets`；页面：`UrlCodecPage.ets`
