# img-base64（Base64 图片预览）

data URI 或裸 Base64 → MIME 解析（头部或魔数：PNG/JPEG/GIF/WebP）、
体积估算（Base64 4 字符 = 3 字节）、规范化 data URI（可给 Image 组件）。

- 演示的 NGF 层：utils
- 纯逻辑：ImgBase64Logic.ets（ImgBase64Test.test.ets 6 条，1x1 PNG 标准向量）
- 页面：ImgBase64Page.ets
- 只做文本级解析与预览，不做缩放或转码。
