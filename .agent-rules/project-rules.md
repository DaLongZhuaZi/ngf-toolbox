# 项目规则 (ngf-toolbox)

> 状态标记: active = 已验证的硬性规则, 必须遵守; candidate = 待验证, 仅供参考。
> 本文件只记本项目专属规则; 通用 ArkTS/框架规范见 AGENTS.md 与 NGF 来源仓规则库。

## active

- PR-001 产品定位: 本 App 是 NGF 框架官方样板应用, 代码质量与注释按教学材料标准; 任何"先凑合"的实现不得合入主干。
- PR-002 隐私: 零遥测/零统计/零账号; 禁止任何数据收集与上报代码。唯一网络功能是端口测试工具连用户输入的主机, 且页面内明示。
- PR-003 权限: module.json5 仅 INTERNET 一项; 新增权限须开发者确认后改本条。
- PR-004 免费: 完全免费, 禁止内购/广告/付费墙代码与配置。
- PR-005 工具架构: 一工具一模块 (entry/src/main/ets/tools/<toolId>/), 逻辑与 UI 分离, 经工具注册表接入; 纯逻辑单元测试覆盖是合入门禁。
- PR-006 框架副本: ngf_framework/ 只读式 vendored (见 VENDORED.md 同步纪律); 业务代码只进 entry/。
- PR-007 版本与命名: 产品名「NGF 开发者工具箱」、包名 com.dlzz.ngftoolbox 不得自行更改; 版本唯一源 AppScope/app.json5。
- PR-008 数据口径: 工具的输入历史与草稿只存本机 (NGF data 层), 不做任何云同步。

## candidate

- PR-C01 工具追加节奏: 上线后按月追加 2-4 件, 顺序由反馈呼声决定 (待首版上线后验证)。
