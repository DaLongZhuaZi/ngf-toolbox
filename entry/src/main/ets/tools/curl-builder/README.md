# curl-builder（HTTP 命令生成）

表单（method/URL/请求头/请求体）→ cURL 与 HTTPie 双命令输出。
URL 缺 scheme 补 https://；Shell 单引号转义；GET 不带 body。

- 演示的 NGF 层：utils
- 纯逻辑：CurlLogic.ets（CurlBuilderTest.test.ets 6 条，输出精确断言）
- 页面：CurlBuilderPage.ets
- 只生成文本命令，不执行（隐私红线：无网络请求由工具发起）。
