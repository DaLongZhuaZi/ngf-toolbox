# jwt-builder（JWT 构建）

HS256 本地签名（**仅演示**）：header 固定 + payload JSON → 三段 base64url token。
组装链复用 codec-suite 编码与 hmac-calc 签名——**JWT.io 官方向量逐字符一致**。

- 演示的 NGF 层：utils、crypto
- 纯逻辑：JwtBuilderLogic.ets（JwtBuilderTest.test.ets 4 条，官方向量）
- 页面：JwtBuilderPage.ets
- 不做密钥强度校验、不加密钥管理；与 jwt-decoder 配对（构建 ↔ 解析验证）。
