# hmac-calc（HMAC 计算）

RFC 2104 HMAC：MD5 / SHA-1 / SHA-256 三算法，密钥 > 64 字节先哈希再补零。
复用 digest 工具的 `HashCore`（utf8Encode + 三个哈希函数）——不复制实现，避免两处漂移。

- 演示的 NGF 层：security、utils
- 纯逻辑：`HmacCalc.ets`（`HmacCalcTest.test.ets` 7 条，**RFC 2202/4231 官方测试向量**）
- 页面：`HmacCalcPage.ets`；文案：`HmacCalcMessages.ets`
- limitation：仅本地计算演示；不做密钥强度评估，不存储任何密钥
