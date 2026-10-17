# NGF 开发者工具箱 (NGF Toolbox)

给鸿蒙开发者的离线微工具聚合：正则测试、JSON 工具、时间戳、编解码、摘要计算、JWT 解码、Cron 解析、端口测试……一个箱子，装下每天用得着的小工具。

**完全免费 · 无广告 · 零遥测 · 默认离线**（仅「端口测试」会连接你自己输入的主机）

> 🚧 建设中：框架接线、工具注册表、正式首页、**首发 16 件工具**与关于页（NGF 专区）均已实现。
> 待办：真机回归与商店物料（属发布决策）。进度与已知边界见 `docs/开发交接.md`。

## 这也是 NGF 框架的官方样板

本应用由 [NGF (Neon Genesis Framework)](https://github.com/DaLongZhuaZi/airwavefootprints) 驱动，并作为它的**官方样板应用**开源：每个工具都对应演示框架的一层能力，想了解 NGF 怎么用，读这个仓库的代码就是最快的路径。

| 工具（示例） | 演示的 NGF 能力 |
|---|---|
| 正则测试 / 编解码 / 摘要 / 时间戳 | utils（纯逻辑层与 UI 解耦、可单测） |
| 工具收藏 / 历史 / 草稿 | data（本地数据层） |
| 工具注册表（加工具 = 注册一项） | core（容器与门面模式） |
| 端口测试 | network |
| 二维码导出与分享 | platformOhos（平台能力适配） |
| 代码查看 | contentSource / contentWorkflow（内容管线） |
| 双主题 | uiTheme（语义色 Token 体系） |
| 中英双语 | i18n |

框架现状（19 个一级目录、API 26 基线、已被上架应用「电波足迹」生产验证）见来源仓的 `docs/NGF_FRAMEWORK_STATUS.md`。

## 首发工具清单（16 件）

**全部可用（16 件）**。下表即「工具 ↔ NGF 层」的映射总表，与 `docs/产品定义.md` §三 同源；
每件工具的目录里另有一份 README，写清它用了哪层、入口在哪。

| # | 工具 | 演示 / 使用的 NGF 能力 |
|---|---|---|
| 1 | 正则测试 | `utils`（纯逻辑与 UI 解耦、可单测） |
| 2 | JSON 工具 | `utils` + `contentWorkflow` |
| 3 | 时间戳 | `utils` |
| 4 | 编解码套件 | `utils` |
| 5 | 摘要计算 | `utils` + `securityToolkit` |
| 6 | JWT 解码 | `utils` |
| 7 | Cron 解析 | `utils` |
| 8 | 进制转换 | `utils` |
| 9 | 日期计算 | `utils` |
| 10 | UUID 与随机密码 | `utils` + `securityToolkit` |
| 11 | 子网计算 | `utils` |
| 12 | 文本 Diff | `contentWorkflow` |
| 13 | **颜色转换** | **`uiTheme`（顺带演示 Token 体系）** |
| 14 | 端口测试 | `network`（**全仓唯一联网工具**，页内明示） |
| 15 | 二维码生成 | `platformOhos`（系统分享、媒体选择） |
| 16 | 代码查看 | `contentSource` + `contentWorkflow`（走系统选择器，不申请存储权限） |

横切能力（每件工具都有，由 `core/` 与 `ui/` 统一提供，不写在单个工具目录里）：
**i18n**（中英双语）、**无障碍**（`accessibilityText` 等）、**关怀模式**（字体缩放四档）、
**深浅双主题**（`uiTheme` Token 取色）、**收藏 / 最近使用 / 输入历史 / 草稿**（`data` 层）。

上线后持续追加（XML/SQL 格式化、条形码、HTTP 速查、JSON↔CSV 等），目标 30+。

## 开发与验证

纯逻辑（`entry/src/main/ets/core/` 与各 `tools/<id>/` 里不依赖设备能力的部分）
可以在**没有 DevEco 的情况下**用 Node 直接跑测试——见 `AGENTS.md` §3.1：

```bash
# 十道门禁（命令与逐条说明见 AGENTS.md §3.1 / §3.2，那是唯一权威来源）
# 本文件不再复制命令清单：复制出来的计数必然过时
#   （这里原先写着「全量单测（573 用例）」而实际是 620，且漏掉了 3 道门禁）
```

## 构建

1. 用 DevEco Studio 打开本工程（HarmonyOS API 26），首次打开时按提示配置自动签名。
2. `entry` 模块依赖同仓的 `ngf_framework` HAR 模块（vendored，见 `ngf_framework/VENDORED.md`），无需额外拉取。
3. CI：推送到 GitHub 后 `build.yml` 会在云端构建未签名 HAP；打 `v*` 标签触发 `sign-and-release.yml` 签名发布（需在仓库 Secrets 配置签名材料，与 airwavefootprints 仓同款流程）。

## 隐私

本应用不收集、不上传任何数据：无统计、无账号、无第三方 SDK。工具的输入历史与草稿只保存在本机。唯一的网络行为是「端口测试」连接你输入的主机:端口，以及你主动打开的外部链接（GitHub 等）。

## 反馈

- GitHub Issues（本仓）
- 官方 QQ 群：1067738499

## 许可证

[MIT](LICENSE) © 2026 DaLongzhuazi

同框架作品：[电波足迹 AirwaveFootprints](https://github.com/DaLongZhuaZi/airwavefootprints)（NGF 生产验证应用）