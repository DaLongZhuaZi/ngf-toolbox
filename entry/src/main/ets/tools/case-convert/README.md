# case-convert（命名风格转换）

一条统一切词规则（小写→大写、字母↔数字、分隔符边界；连续大写保持成词）把任意标识符切成词数组，
再按目标风格拼回。输出六种：camel / Pascal / snake / SCREAMING / kebab / dot。

- 演示的 NGF 层：utils
- 纯逻辑：`CaseConvert.ets`（零 import，`CaseConvertTest.test.ets` 9 条，含 round-trip 幂等断言）
- 页面：`CaseConvertPage.ets`；文案：`CaseConvertMessages.ets`
