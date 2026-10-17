# semver-parse（SemVer 解析）

SemVer 2.0.0：主/次/补丁/先行版本/构建元数据拆解 + v 前缀容错 +
**完整优先级比较器**（先行版本逐标识符比较、数字按数值、正式版 > 先行版）。

- 演示的 NGF 层：utils
- 纯逻辑：SemverLogic.ets（SemverParseTest.test.ets 7 条，含规范比较链）
- 页面：SemverPage.ets
- 不做版本范围（^ ~ x.y.z）判断。
