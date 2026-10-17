# changelog-gen（Changelog 生成器）

Conventional Commits 归类：feat/fix/docs/style/refactor/perf/test/build/ci/chore/revert
十一种类型，scope 拆除、subject 首字母大写、非规范行归 Other 兜底。
输出 Markdown 分节（feat→Features、fix→Bug Fixes…）。

- 演示的 NGF 层：utils、contentWorkflow
- 纯逻辑：ChangelogLogic.ets（ChangelogGenTest.test.ets 7 条）
- 页面：ChangelogGenPage.ets
- 不读取 git 历史——用户粘贴提交清单（避免引入命令执行）。
