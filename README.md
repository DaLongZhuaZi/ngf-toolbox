# NGF 开发者工具箱 (NGF Toolbox)

给鸿蒙开发者的离线微工具聚合：正则测试、JSON 工具、时间戳、编解码、摘要计算、JWT 解码、Cron 解析、端口测试……一个箱子，装下每天用得着的小工具。

**完全免费 · 无广告 · 零遥测 · 默认离线**（仅「端口测试」会连接你自己输入的主机）

> 🚧 建设中：当前仓库为工程脚手架（框架已就位、工具开发中），首发 16 件工具清单见下方与 `docs/产品定义.md`。

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

正则测试 · JSON 工具 · 时间戳 · 编解码套件 · 摘要计算 · 二维码生成 · 代码查看 · 端口测试 · JWT 解码 · Cron 解析 · 子网计算 · 进制转换 · 颜色转换 · UUID 与随机密码 · 文本 Diff · 日期计算

上线后持续追加（XML/SQL 格式化、条形码、HTTP 速查、JSON↔CSV 等），目标 30+。

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
