# text-diff

**文本 Diff**（Text Diff）。NGF 开发者工具箱的一件工具，本目录自包含。

## 用了哪层 NGF

- `contentWorkflow` —— 动作执行与重试

## 入口在哪

`TextDiffPage.ets` 导出 `buildTextDiffPage`，由 `ui/ToolPageRegistry.ets` 登记进工具页路由。
页面组件本身只负责 UI；算法在下面的纯逻辑文件里，因此能在本机跑单测（不需要设备）。

## 文件构成

| 文件 | 作用 |
|---|---|
| `TextDiff.ets` | **纯逻辑**（零 ArkUI 依赖，有单测） |
| `TextDiffMessages.ets` | 失败码 → 资源键的文案映射（i18n） |
| `TextDiffPage.ets` | 页面组件 + `@Builder` 入口 |

单测在 `entry/src/test/`，覆盖上表的纯逻辑文件。
