# AGENTS

本文件是 **NGF 开发者工具箱（ngf-toolbox）** 仓库的统一代理工作规范。任何 Agent（桌面端 / 沙箱 / 其他）在本仓动手前先读本文件与 `.agent-rules/project-rules.md` 的全部 active 条目。

## 1. 仓库定位

- 本仓是一个独立的 HarmonyOS 应用工程：`entry/` 是应用（NGF 开发者工具箱），`ngf_framework/` 是 vendored 的 NGF 框架副本（见 `ngf_framework/VENDORED.md`）。
- 本 App 是 **NGF 框架的官方样板应用**：代码本身就是给框架使用者看的教学材料，注释与分层纪律按「给陌生开发者读」的标准执行。
- 产品定义（定位、工具清单、交互规范、质量门禁）以 `docs/产品定义.md` 为准；开发交接状态以 `docs/开发交接.md` 为准。两者冲突时先问开发者，不要自行裁决。

## 2. 硬性规则

- 文件读写一律显式 UTF-8。
- ArkTS 规范从严：禁止 `any`/`unknown`、禁止模板字面量（用字符串拼接）、显式类型标注、异常捕获必须处理。细则沿用 NGF 来源仓（airwavefootprints）的 `.rules/skill-arkts-standards.md`，本仓不复述。
- 修改代码默认**不自动跑 hvigor 构建**；构建验证走 CI（`.github/workflows/build.yml`），或由开发者明确要求时本地构建。
- 对侵入性/高风险修改，先在同目录做 `*.bak` 备份再动手。
- **隐私红线**：本 App 零遥测、零统计、零账号；不得引入任何数据收集 SDK 或自建上报。唯一网络用途是「端口测试」工具连接用户自己输入的主机，且必须在该工具页面内明示。
- **权限红线**：`entry/src/main/module.json5` 只允许 `ohos.permission.INTERNET` 一项；新增任何权限必须先经开发者确认并记入 `.agent-rules/project-rules.md`。
- **免费红线**：本 App 完全免费，不得加入内购、广告、付费解锁相关代码或配置。

## 3. 工具开发约定

- 每个工具一个独立模块目录：`entry/src/main/ets/tools/<toolId>/`，内含页面组件与纯逻辑文件；逻辑与 UI 分离，纯逻辑必须有单元测试（`entry/src/test/`）。
- 工具只能通过**工具注册表**接入首页（注册表在功能阶段建立，见开发交接），禁止在首页硬编码跳转到具体工具实现细节之外的耦合。
- 工具的输入/输出交互遵循产品定义稿的统一模板（输入区 → 处理 → 输出区 → 复制/历史/清空，输入自动存草稿）。
- 新增工具准绳：纯本地可实现、能映射到 NGF 某一层能力、过质量门禁（单测 + 真机回归）才可上架。

## 4. 框架副本纪律

- `ngf_framework/` 是 vendored 副本：框架改动原则上回来源仓（airwavefootprints）修改验证后再同步；本仓内的先行试验必须在 `ngf_framework/VENDORED.md` 追记。
- 不要在本仓给框架加业务逻辑；工具箱业务只写在 `entry/`。

## 5. 已定事项（不要再议）

- 产品名：NGF 开发者工具箱；包名：`com.dlzz.ngftoolbox`；仓库：`DaLongZhuaZi/ngf-toolbox`；许可证：MIT；完全免费；开源。
- 版本：`AppScope/app.json5` 的 versionName/versionCode 是唯一版本源，发布时两处（app.json5 与 Release tag）保持一致。
- 签名：仓库不提交签名材料；本地用 DevEco 自动签名，CI 剥离签名出未签名包，发布签名走 sign-and-release（v* tag + Secrets）。
