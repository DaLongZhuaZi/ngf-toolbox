# md-link-check（Markdown 链接检查）

提取 [text](target) 与 ![alt](src)，四类分类（锚点/相对/绝对/其它协议）、
重复 target 检测、空 target 计数、行号定位。不发网络请求，纯文本检查。

- 演示的 NGF 层：utils、contentWorkflow
- 纯逻辑：MdLinkCheckLogic.ets（MdLinkCheckTest.test.ets 6 条）
- 页面：MdLinkCheckPage.ets
- 不校验链接可达性（那需要网络，违反隐私红线）。
