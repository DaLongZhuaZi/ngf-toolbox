# ip-cidr（IP/CIDR 计算器）

CIDR 速查：网络地址、广播地址、掩码、**通配符掩码**（网络设备配置高频）、地址总数。
复用 subnet-calc 的 ipToValue/valueToIp/prefixToMaskValue——不复制实现。

- 演示的 NGF 层：utils、network
- 纯逻辑：`IpCidr.ets`（`IpCidrTest.test.ets` 5 条，/25 与 /0 手算基准）
- 页面：`IpCidrPage.ets`；文案：`IpCidrMessages.ets`
- 移位运算用除法表达（hypium 对超 31 位 >>> 不可靠，checksum 同款教训）
