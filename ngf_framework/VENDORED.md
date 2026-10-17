# ngf_framework vendored snapshot

本目录是 NGF (Neon Genesis Framework) 的完整 vendored 副本, 随样板应用一起分发,
保证 clone 即可构建, 不依赖外部模块仓库。

- 来源仓库: DaLongZhuaZi/airwavefootprints (框架长期维护仓)
- 来源提交: 456594996b65961196a763b6d0865d5a96d99821 (2026-10-11)
- 拷入日期: 2026-10-16
- 框架版本: ngf_framework oh-package.json5 version = 1.0.0, MIT
- 框架现状: 见来源仓 docs/NGF_FRAMEWORK_STATUS.md (2026-10-16 全量重扫版)

同步纪律: 框架的修改应在来源仓完成并验证后再同步进本目录, 不要只改本目录的副本;
确需在本仓先行试验的框架改动, 必须在本文件追记一行 (日期/改动/回同步状态)。

## 本仓先行修改（需回来源仓 airwavefootprints 同步）

### 2026-10-16 `deviceAwareness/index.ets`：补 `AccessibilityFacade` 导出

**现象**：`deviceAwareness/facades/AccessibilityFacade.ets` 文件存在且实现完整
（`isAccessibilityEnabled` / `isScreenReaderEnabled` / `buildAccessibilityLabel` /
`buildAccessibilityHint`），但 `deviceAwareness/index.ets` 里没有对应的 `export`，
于是 `import { ngfAccessibilityFacade } from 'ngf_framework'` 拿不到它。

**影响**：无障碍是官方样板应用必须演示的能力，拿不到门面就只能绕过框架直接调
`@ohos.accessibility`，那与本项目「样板」的定位相悖。

**本仓改动**：在 `deviceAwareness/index.ets` 增加一行
`export { ngfAccessibilityFacade, NGFAccessibilityState } from './facades/AccessibilityFacade';`

**待办**：回来源仓补同样的一行，验证后同步回来；同步回来时应删除本追记。

### 2026-10-16 `uiTheme`：`NGFColorToken` 补 5 个语义色 Token

**缺口**：MD3 基准的 20 个 Token 里没有「错误容器 / 警告 / 警告容器 / 成功」。
而工具箱自建色表里有 `error_background` / `warning` / `warning_background` /
`success` 四个键（合计 70 处引用），迁移到 Token 时**无处安放**——
只能被迫保留一份自建 `color.json`，那就失去了「统一走 Token」的意义。

**本仓改动**：
- `uiTheme/contracts/IColorTokenProvider.ets`：`NGFColorToken` 增加
  `ERROR_CONTAINER` / `ON_ERROR_CONTAINER` / `WARNING` / `WARNING_CONTAINER` / `SUCCESS`。
  其中前两个是 **MD3 规范本就有**的槽位（`errorContainer` / `onErrorContainer`），属补齐遗漏；
  后三个是通用应用语义色，HDS 设计体系亦有定义。
- `uiTheme/facades/ColorTokenProviderFacade.ets`：`registerDefaults()` 补对应默认值。

**待办**：回来源仓补同样的枚举成员与默认值，验证后同步回来；同步回来时应删除本追记。

### 2026-10-16 `uiShell`：`NGFNavigationParamEnvelope` 补 `export`

**现象**：`NavigationShellFacade.push(pageName, paramsJson)` 会把参数包成
`NGFNavigationParamEnvelope { payloadJson: string }` 再 `pushPathByName`，
但**这个类不是导出的**（全仓只有该门面自己引用它）。

**影响**：接收方（`navDestination` 的 builder）拿到的形参类型是 `Object`，
而 ArkTS 的 `arkts-no-structural-typing` 禁令让调用方**无法结构化地读** `payloadJson`，
除非 `as` 到一个本地同形状的类（靠约定维持，框架一改就静默失效）。
换言之：走这个门面传参，参数其实**取不出来**。

**本仓改动**：给该类加 `export`，并在 `uiShell/index.ets` 转出。

**待办**：回来源仓补同样的导出，验证后同步回来；同步回来时应删除本追记。

### 2026-10-16 `uiShell`：`NGFHdsImmersiveTabs` 三个配置项去掉 `private`

**现象**：`NGFHdsTabsFactory.ets` 里，`items` / `selectedIndex` / `onChangeCallback`
被声明成 `private`，而它们正是**父组件必须传入的配置**（`@BuilderParam contentBuilder`
反倒没标 private，可见是漏标而非有意）。

**后果是静默的**：ArkTS 只给三行 WARN
（`Property 'X' is private and can not be initialized through the component constructor`），
编译照过。运行时 `items` 保持空数组 → **页签一个都不渲染**；
`onChangeCallback` 保持空实现 → **点页签没反应**。

**发现途径**：增量构建不重报 ArkTS 告警，这个警告被藏了多轮，是**全量重编**时才暴露的。
见 `tools/verify/build.ps1` 的告警归属统计。

**本仓改动**：三处去掉 `private`（`controller` 与 `effectiveMaterialLevel` 保持私有，它们是内部状态）。

**待办**：回来源仓补同样的修改，验证后同步回来；同步回来时应删除本追记。

### 2026-10-16 `uiShell/README.md`：补写 components/ 说明

**问题**：该 README 原文只有两句——「定义导航壳层与页面策略宿主契约」「**暂不改动业务页面**」——
而它旁边的 `components/` 里有 **8 个组件、约 2034 行**完整实现
（`NGFHdsTabsFactory` / `NGFImmersiveTopChrome` / `NGFPageTemplates` /
`NGFHdsEffectPresets` / `NGFMaterialSurfaceTokens` / `HdsNavigationSupport` /
`AboutSheetContent` / `NGFControlStyleTokens`）。

「暂不改动业务页面」读起来像「这里没什么可用的」，**与事实相反**。
这不是纯文档瑕疵：使用本框架的样板仓首版就因此整体忽略了这批组件，
手搓了一套壳层与主题层，直到返工时才发现。

**本仓改动**：重写 README，列出 components/ 的实际内容、各自提供什么、
以及三条最容易踩的坑（`private` 声明导致不渲染、底板避让、资源键跨模块覆盖）。

**待办**：回来源仓同步这份 README；同步回来时应删除本追记。

### 2026-10-16 `NGFHdsImmersiveTabs`：**带参 `@BuilderParam` 在真机上不渲染内容**（缺陷，待修）

**现象**（真机实测，手机 1600×2560，API 26）：

- 底部页签条**正常显示**（收藏 / 文本与数据 / 编解码与计算 / 网络 / 文件与生成）；
- **`TabContent` 里一个像素都不渲染**——首页内容区整块空白。

**判定依据**：首页那个 `@Builder` 里有一个**无条件渲染**的小标题（「收藏」「最近使用」），
它也没有出现。所以不是「内容为空」，而是**父组件传进来的 builder 根本没被调用**。

**旁证**：grep 整个框架，**带参数的 `@BuilderParam` 只有这一处**
（`contentBuilder: (index: number) => void`）；
`NGFPageTemplates` 的五个 `@BuilderParam`（headerBuilder / contentBuilder /
footerBuilder / footerSlot / formFields）**全是无参形式**。

也就是说「**带参 `@BuilderParam`，父组件传 `this.method` 方法引用，子组件在
`ForEach` 的 `TabContent` 里调用**」这条路径在本框架里**从未被验证过**，
而它是本组件对外提供内容的唯一通道。

**已做的处置**（本仓先行，非框架侧修复）：

样板仓**不再使用** `NGFHdsImmersiveTabs` 渲染首页内容，
改为在同组件内自绘分类页签条（`pages/Index.ets` 的 `buildCategoryTabs`）。
沉浸式顶栏、Token 取色、i18n、无障碍均不受影响。

**待办（回来源仓）**：定位带参 `@BuilderParam` 的正确调用形式并修复本组件，
或在文档中明确写出该限制；修好后样板仓可以切回去。

**注意**：本组件至今**没有任何使用示例**（框架内引用只有 `uiShell/index.ets` 的导出），
所以这条缺陷此前不可能被发现。

### 2026-10-17 `HdsNavigationSupport`：新增 `buildAdaptive()`——主题自适应标题栏

**问题**（样板仓真机截图确认）：原 `build()` 把标题/副标题色写死成 `app.color.text_white`，
这是「恒深底板 + 白字」的沉浸式形态（原版 MainMenuPage 图片头页合理）。但工具类列表页
背景跟随系统深浅色，浅色主题下白字压浅底读不出来，宿主被迫把底板染成恒深渐变
（样板仓 `FULLSCREEN_CHROME`），结果出现「顶部深块 + 浅色内容」的生硬分界，
且副标题白字压在渐变边缘对比度不足。

**本仓改动**：新增 `static buildAdaptive(主标题, 副标题, 背景, 滚动后背景, 标题色, 副标题色, 材质档位, avoid, component)`。
**不改原 `build()`**——来源仓行为保持不变。新方法的滚动光效（GRADIENT_BLUR）与材质管线
（IMMERSIVE）复用本类既有私有类，未新增依赖。

**样板仓用法**：三个调用点（首页/工具页/关于页）改传主题 Token 色与同色系滚动底，
底板不再恒深。

**待办（回来源仓）**：评估把该变体并入 `build()`（加可选参数），验证后同步。
