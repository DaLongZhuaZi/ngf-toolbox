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
- PR-009 纯逻辑验证: 纯逻辑改动合入前必须在本机跑通单测 —— `node --import ./tools/verify/register.mjs tools/verify/run.mjs`
  必须 0 失败, 且 `... run.mjs --logic` 必须 0 失败。理由: CI 只做构建不跑单测, 真机回归成本高;
  没有本机验证等于算法正确性无人把关。新增测试文件后须跑 `node tools/verify/gen-test-entry.mjs`
  重新生成 hypium 总入口 (漏登记 = 测试在真机上从不执行)。
- PR-014 注释闭合安全: 注释内禁止出现「星号 + 斜杠」的相邻组合 (典型误写: 用星号加粗的
  "斜杠数字" 前缀写法), 否则块注释提前闭合, 报错为难懂的 "Expected ';', '}' or <eof>" 且无行号。
  写前缀请用「前缀 24」这样的文字表述。合入前跑 `node tools/verify/scan-comments.mjs` 须 0 问题。
- PR-013 资源引用字面量: `$r()` 入参必须是字符串字面量, 禁止拼接 (ets-loader 构建期按字面量
  静态改写, 拼接无效且不报错)。动态资源须建字面量表, 范例见 entry/src/main/ets/ui/ToolSymbols.ets。
- PR-012 接线一致性: 新增/删除工具后必须跑 `node tools/verify/check-wiring.mjs` 且 0 问题。
  理由: 「加一件工具」要同时改目录/元数据/页面注册表/单测/总入口五处, 漏改任一处都不报错,
  而是静默降级为「首页没入口」「点进去建设中」或「真机从不执行该测试」。
- PR-011 页面结构检查: 改动或新增 `*Page.ets`/`ui/*.ets` 后必须跑
  `node tools/verify/check-pages.mjs` 且 0 问题。理由: 页面文件本地无法编译验证, CI 反馈慢,
  而组件名拼错 / @Builder 漏括号 / build() 提前 return 都是静态可判定的常见翻车点。
- PR-010 类型别名导入: 纯逻辑文件中禁止把类型别名与运行时值写进同一条 import 语句
  (ArkTS 剥离类型时会丢掉整条语句, 连带丢掉同条内的枚举值)。类型别名单独一条 import。

## candidate

- PR-C01 工具追加节奏: 上线后按月追加 2-4 件, 顺序由反馈呼声决定 (待首版上线后验证)。
