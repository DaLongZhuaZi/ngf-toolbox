# sql-format（SQL 格式化）

文本级重排：关键字大写（大小写不敏感识别，词边界整词替换）、
主子句（SELECT/FROM/WHERE/ORDER BY/GROUP BY/LIMIT/JOIN 等）换行顶格、
AND/OR 换行两空格缩进、字符串字面量内容原样保护（不大写不换行）。

- 演示的 NGF 层：utils、contentWorkflow
- 纯逻辑：SqlFormat.ets（SqlFormatTest.test.ets 8 条）
- 页面：SqlFormatPage.ets
- 不解析语法树、不校验 SQL 合法性；方言差异（窗口函数/CTE）不特殊处理。
