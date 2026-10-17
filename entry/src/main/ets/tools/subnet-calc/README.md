# subnet-calc

**子网计算**（Subnet Calculator）。NGF 开发者工具箱的一件工具，本目录自包含。

## 用了哪层 NGF

- `utils` —— 纯计算，不碰设备

## 入口在哪

`SubnetCalcPage.ets` 导出 `buildSubnetCalcPage`，由 `ui/ToolPageRegistry.ets` 登记进工具页路由。
页面组件本身只负责 UI；算法在下面的纯逻辑文件里，因此能在本机跑单测（不需要设备）。

## 文件构成

| 文件 | 作用 |
|---|---|
| `SubnetCalc.ets` | **纯逻辑**（零 ArkUI 依赖，有单测） |
| `SubnetCalcMessages.ets` | 失败码 → 资源键的文案映射（i18n） |
| `SubnetCalcPage.ets` | 页面组件 + `@Builder` 入口 |

单测在 `entry/src/test/`，覆盖上表的纯逻辑文件。
