# checksum（校验和）

CRC-32（IEEE 802.3，reflected，查表法）与 Adler-32（RFC 1950）。
**完整性校验而非加密哈希**——碰撞可构造，不用于防篡改。输入 UTF-8 编码后按字节计算。

- 演示的 NGF 层：utils、security
- 纯逻辑：`Checksum.ets`（`ChecksumTest.test.ets` 7 条，**IEEE/RFC 官方向量**）
- 页面：`ChecksumPage.ets`；文案：`ChecksumMessages.ets`
- 实现注记：逻辑右移用「除二取整」表达（hypium 对超 31 位值的 >>> 不可靠，第 81 轮实测）
