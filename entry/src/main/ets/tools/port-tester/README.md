# port-tester

**端口测试**（Port Tester）。NGF 开发者工具箱的一件工具，本目录自包含。

## 用了哪层 NGF

- `network` + `@kit.NetworkKit` socket

> ⚠️ **本工具会联网**（连接用户自己输入的主机），页内有明示。全仓只有这一件联网。

## 入口在哪

`PortTesterPage.ets` 导出 `buildPortTesterPage`，由 `ui/ToolPageRegistry.ets` 登记进工具页路由。
页面组件本身只负责 UI；算法在下面的纯逻辑文件里，因此能在本机跑单测（不需要设备）。

## 文件构成

| 文件 | 作用 |
|---|---|
| `PortMessages.ets` | 失败码 → 资源键的文案映射（i18n） |
| `PortTester.ets` | **纯逻辑**（零 ArkUI 依赖，有单测） |
| `PortTesterPage.ets` | 页面组件 + `@Builder` 入口 |

单测在 `entry/src/test/`，覆盖上表的纯逻辑文件。
