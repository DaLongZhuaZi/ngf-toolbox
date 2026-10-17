# file-hash（文本哈希校验）

一次输入输出 MD5/SHA-1/SHA-256/SHA-512 四个哈希（发布校验场景：无论发布方
给哪个算法都能对上）+ 与期望值比对（大小写/空格/0x 前缀容错）。
薄封装 digest 的 HashCore（同一实现，与交叉验证门禁同源）。

- 演示的 NGF 层：utils、crypto
- 纯逻辑：FileHashLogic.ets（FileHashTest.test.ets 7 条，已知向量）
- 页面：FileHashPage.ets
- 范围：文本输入（真实文件的分块读取是后续增强）。
