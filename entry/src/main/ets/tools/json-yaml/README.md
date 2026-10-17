# json-yaml（YAML 解析）

YAML 子集转 JSON 单向。支持：顶层标量键值对、一层嵌套对象（两空格缩进）、
行内数组、整行注释、null/~ 哨兵。
不支持：多行块标量（明确报错）、两层以上嵌套、锚点引用、多文档分隔符（明确报错）。

- 演示的 NGF 层：utils、data
- 纯逻辑：JsonYaml.ets（JsonYamlTest.test.ets 9 条）
- 页面：JsonYamlPage.ets
- 实现注记：plain scalar（未加引号的裸文本）是 YAML 合法标量——与 TOML 的关键差异；
  null 字面量用哨兵对象区分「解析失败」。
