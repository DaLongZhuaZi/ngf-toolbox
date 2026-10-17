# password-strength（密码强度评估）

薄封装 uuid-password 的评估器（熵上界估算 + 结构性扣分）。
本工具增量：score 0-4 → 弱/中/强三档总结、建议按「长度类 < 字符类 < 模式类」优先级。

- 演示的 NGF 层：utils、crypto
- 纯逻辑：PasswordStrengthLogic.ets（PasswordStrengthTest.test.ets 5 条）
- 页面：PasswordStrengthPage.ets（建议文案复用 UuidPasswordMessages）
- 口径：熵是理论上界，不查泄露库、不做字典攻击模拟（离线启发式）。
