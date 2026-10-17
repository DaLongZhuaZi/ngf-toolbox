# uuid-batch（UUID 批量生成）

薄封装 uuid-password 的 generateUuidBatch：v4 批量 + 大小写/连字符开关 +
逐条复制与全部复制。纯逻辑零新增——随机源实现与安全约束（绝不降级 Math.random）与原件一致。

- 演示的 NGF 层：utils、crypto
- 纯逻辑：复用 ../uuid-password/UuidPasswordLogic.ets（已有单测覆盖）
- 页面：UuidBatchPage.ets
