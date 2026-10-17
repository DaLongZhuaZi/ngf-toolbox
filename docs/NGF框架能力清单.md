# NGF 框架能力清单

> 本文件是 **`AGENTS.md` §0 指定的必读**，优先级高于该文件其余部分。
> 它回答一个问题：**框架里已经有什么、怎么用、对应产品定义稿哪一条。**

## 为什么需要这份清单（血泪教训）

首版开发时，Agent 只按符号去 grep 框架代码，从没盘点过「框架有哪些层、每层提供什么」。
于是手搓了一套壳层（`Index.ets` 网格 + `ToolScaffold`）和主题层（自建两份 `color.json`），
把框架**已经做好并实测过**的沉浸式顶栏、HdsTabs、页面模板、颜色 Token 体系、
无障碍门面、字体缩放（关怀模式）全部丢掉了——

而 `docs/产品定义.md` §3.1 第 56 行明确写着「壳导航（core + uiShell）」「深浅双主题（uiTheme）」。

**代价是一轮完整返工。** 这份清单就是那次返工的产物与依据。

## 怎么用

1. **新增任何 UI / 主题 / 无障碍 / 字体相关的代码前**，先在 §一 与 §三 里查框架有没有现成的；
2. 有就用；**没有或确实不适用，在 §三 里记一条「为什么不用」**，再自己写；
3. §四 是「当前 app 用到了什么」的差距表，§六 是返工计划。

## 章节

- **§一 框架分层总表** —— 18 个层各自负责什么
- **§二 四项基础能力的框架 API** —— i18n / 无障碍 / 关怀模式 / 主题配置（含颜色 Token 的语义色缺口）
- **§三 壳层组件** —— uiShell 提供的组件，以及三处「刻意不用」的理由
- **§四 当前 app 的实际使用情况** —— 差距表
- **§五 框架侧待修** —— 框架自身的问题（按 §4 回来源仓，不在本仓改）
- **§六 返工计划** —— 按依赖顺序

## 一、框架分层总表

`ngf_framework/src/main/ets/` 下 18 个层，各层都有 `index.ets` 作为对外出口：

| 层 | 职责 | 对本项目的重要性 |
|---|---|---|
| `uiShell` | 导航壳层、页面策略、覆盖层、**HDS 组件** | ★★★ 壳层重构的主战场 |
| `uiTheme` | 主题、**颜色 Token**、**字体缩放（关怀模式）**、组件级主题覆盖 | ★★★ 四项基础能力里占两项 |
| `i18n` | 多语言、翻译资源、相对时间 | ★★★ |
| `deviceAwareness` | 设备适配、断点布局、**无障碍**、视觉效果/材质、能力探测 | ★★★ 无障碍在这层 |
| `data` | 设置存储、关系库、缓存、迁移 | ★★ 收藏/最近使用/草稿已用一部分 |
| `core` | 事件总线、启动内核、错误处理、生命周期 | ★★ |
| `platformOhos` | UIContext 管理、系统集成、分享、窗口 | ★★ |
| `contentSource` / `contentWorkflow` | 内容源与流水线 | ★ 代码查看器可能用得上 |
| `media` | 媒体选择、播放器组件 | ★ 二维码分享已用 |
| `security` | 密钥库、加解密、摘要 | ★ 摘要工具已用 |
| `network` (2 行) / `push` / `interconnect` / `webBridge` / `hardware` / `systemTasks` / `utils` | 各自领域 | 按需 |

## 二、四项基础能力的框架 API（已核对）

### 2.1 i18n —— 层 `i18n`

```ts
import { ngfI18nManagerFacade, ngfRelativeTimeFormatterFacade,
         ngfTranslationResourceFacade, resolveResourceString } from 'ngf_framework';
```

- `ngfI18nManagerFacade.resolveString(key: string | Resource): string`
- `ngfI18nManagerFacade.resolveStringWithArgs(key: string | Resource, args: Array<string | number>): string`
- 另有 `ngfRelativeTimeFormatterFacade`（相对时间，"3 天前" 这类）——
  **本项目 uuid-password/jwt-decoder 手写了相对时间，应改用它**。
- `resolveResourceString`：从资源 ID 解析字符串的底层工具。

**当前用法**：`ui/ToolUiKit.stringOf` 已经包了 `resolveString` / `resolveStringWithArgs`——
这一条是**用对了的**，唯一的问题是它自己是个中间层，不能 `import ArkUI` 的纯逻辑层需要另想办法。

### 2.2 无障碍 —— 层 `deviceAwareness`

```ts
// ⚠️ 目前**不能**从 'ngf_framework' 顶层导入，见「五、框架侧待修」
import { ngfAccessibilityFacade } from 'ngf_framework/src/main/ets/deviceAwareness/facades/AccessibilityFacade';
```

已核对的方法：

| 方法 | 用途 |
|---|---|
| `isAccessibilityEnabled(): boolean` | 系统无障碍是否开启 |
| `isScreenReaderEnabled(): boolean` | 读屏是否开启（决定要不要降级动效/加长提示） |
| `buildAccessibilityLabel(componentId: string, label: string): string` | 组装无障碍标签 |
| `buildAccessibilityHint(action: string): string` | 组装操作提示 |

导出常量：`NGFAccessibilityState`。

**当前用法**：**0 处**。整个 app 没有任何 `accessibilityText` / `accessibilityDescription` /
`accessibilityLevel` / `accessibilityGroup`，也没调用过这个门面。**这是必须补的基础能力。**

### 2.3 关怀模式 / 字体缩放 —— 层 `uiTheme`

注意：**它在 `uiTheme` 层，不在 `deviceAwareness`**。

```ts
import { ngfFontScaleManagerFacade, NGFFontScaleLevel } from 'ngf_framework';
```

| 方法 | 用途 |
|---|---|
| `getCurrentScale(): number` | 当前缩放倍率 |
| `getCurrentLevel(): NGFFontScaleLevel` | 当前档位 |
| `setFontScaleLevel(level: NGFFontScaleLevel)` | 按档位设置（关怀模式用） |
| `setCustomScale(scale: number)` | 自定义倍率 |
| `resetToSystem()` | 恢复跟随系统 |
| `getScaleForLevel(level): number` | 档位 → 倍率的换算 |
| `onScaleChanged(cb)` / `offScaleChanged(cb)` | 订阅变化 |

**当前用法**：**0 处**。页面里的字号全是硬编码 `fontSize(14)` 这类字面量，
系统放大字体时不会跟。**这是必须补的基础能力。**

### 2.4 主题配置 —— 层 `uiTheme`

```ts
import { ngfThemeManagerFacade, ngfColorTokenProviderFacade,
         ngfComponentThemeOverride, NGFThemeMode } from 'ngf_framework';
```

**主题管理**

| 方法 | 用途 |
|---|---|
| `getCurrentTheme()` / `isDarkMode()` | 当前主题 |
| `setThemeOverride(mode: NGFThemeMode)` / `clearThemeOverride()` | 手动覆盖 / 恢复跟随系统 |
| `onThemeChanged(cb)` / `offThemeChanged(cb)` | 订阅变化 |
| `handleSystemColorModeChanged(colorMode)` | 系统深浅色变化 |
| `loadThemePack(pack)` / `applyThemePack()` | 主题包 |
| `initializeDefaults()` | 初始化默认值 |

**颜色 Token**

| 方法 | 用途 |
|---|---|
| `resolveColor(token: NGFColorToken)` | Token → 颜色 |
| `resolveColorValue(token)` | Token → 颜色值 |
| `registerColor(value: NGFColorValue)` | 注册自定义色 |
| `registerDefaults()` | 注册默认色表 |

还有 `ngfComponentThemeOverride` + `NGFThemeOverridePresets`（组件级主题覆盖）。

**当前用法**：**0 处**。本项目自建了两份 `resources/base|dark/element/color.json`（各 14 个键），
并用自写的 `tools/verify/check-theme-contrast.mjs` 审计对比度。
**这套自建物应当整体替换为 Token 体系**，颜色转换工具还要顺带演示 Token（产品定义稿第 51 行）。

### 2.5 颜色 Token 的语义色缺口（本仓已先行补齐）

MD3 基准的 `NGFColorToken` 是 20 个，**没有状态反馈色**：
`error_container` / `warning` / `warning_container` / `success` 四个槽位缺失，
而工具箱自建色表里恰好有 `error_background` / `warning` / `warning_background` /
`success`（70 处引用）。

本仓已补 5 个成员（`ERROR_CONTAINER` / `ON_ERROR_CONTAINER` / `WARNING` /
`WARNING_CONTAINER` / `SUCCESS`），现共 **25 个**，详见 `ngf_framework/VENDORED.md`。

## 三、壳层组件（层 `uiShell`，均已核对存在且有实现）

| 导出 | 说明 | 该替换掉本项目的什么 |
|---|---|---|
| `NGFHdsImmersiveTabs` / `NGFHdsTabItem` | HdsTabs 封装，用 `@kit.UIDesignKit` + IMMERSIVE 材质 | 自建 `Index.ets` 工具网格 |
| `ngfImmersiveContentTop` / `NGFImmersiveTopChromeUnderlay` / `NGFImmersiveTopChromePresetFactory` / `NGFImmersiveTopChromeSpec` | 沉浸式顶栏（含实测避让高度） | 自建 `ToolScaffold` 标题区 |
| `NGFListPageTemplate` / `NGFDetailPageTemplate` / `NGFFormPageTemplate` / `NGFKeyValueEntry` | 三种开箱页面骨架 | 自建 `ToolScaffold` |
| `NGFControlStyleTokens` | 控件尺寸/圆角/字号 Token | 页面里硬编码的尺寸 |
| `NGFHdsTitleBarOptionsFactory` | HdsNavigation 标题栏 | 自建标题栏 |
| `ngfNavigationShellFacade` | 导航壳层门面 | 自建 `ToolNavigator` + `Navigation` |
| `ngfPageTransitionManager` / `ngfPageStateStoreFacade` | 页面转场 / 页面状态 | 无 |
| `ngfOverlayManagerFacade` | Toast 等覆盖层 | **已用**（`ToolUiKit.toast`） |
| `AboutSheetContent` | **关于页内容组件** | 自建 `pages/AboutPage.ets` + `about/AppInfo.ets` |
| `NGFHdsEffectPresetFactory` / `NGFHdsMaterialSurfacePreset` 等 | 交互效果与材质预设 | 无 |
| `ngfDragDropManagerFacade` | 拖拽 | 无 |

### 3.1 为什么工具页**不用** NGFPageTemplates（按 §0 记录「不适用」）

`NGFListPageTemplate` / `NGFDetailPageTemplate` / `NGFFormPageTemplate` 是三种
**列表 / 详情 / 表单**页骨架，而工具页的统一交互是
「输入区 → 一键处理 → 输出区 → [复制][清空]」（产品定义稿 §四）。

两者的形状不一样：
- 表单模板的语义是「填字段 → 提交」——工具页没有「提交后跳走」这一步，
  而是要**在原地展示输出**，且输出区往往比输入区更重要（JSON 格式化、Diff、二维码）。
- 列表/详情模板更是对不上。

硬套的结果会是「为了用框架而扭曲交互」。所以：
- **用**：`NGFImmersiveTopChromeUnderlay`（沉浸式底板）——它解决的是背景与避让，与交互形状无关；
- **不用**：三种页面模板。若将来某个工具天然是列表或表单形状（例如追加池里的
  「HTTP 状态码速查」是纯列表），**那个工具应当用 `NGFListPageTemplate`**。

### 3.2 导航壳层：整体迁移（**已执行**）

**框架的契约**（`uiShell/facades/NavigationShellFacade.ets`）：

- `push(pageName, paramsJson)` / `pop()` / `replace(pageName, paramsJson)` /
  `currentPageName()` / `pushWithIntercept(...)`（异步，走 `ngfRouteInterceptorFacade`）
- 导航栈的来源是 `AppStorage.get<NavPathStack>('GlobalNavStack')`——
  **即 App 必须自己建 NavPathStack 并以这个键放进去**，框架不会代建。
- 参数不是直接传对象，而是被包成 `NGFNavigationParamEnvelope { payloadJson: string }`
  （JSON 字符串）。好处是拦截器可以审查/改写参数。

**当前 App 的状况**：用的是**页面 Router**（`uiContext.getRouter().pushUrl(...)`），
`ToolHostPage` / `AboutPage` 是两个 `@Entry` 页面、登记在 `main_pages.json`。
这与 `NavPathStack` 是**两套不同的导航体系**，不能局部替换。

**迁移要动的**：Index 建 `NavPathStack` 并写入 `GlobalNavStack` →
`Navigation(this.pathStack)` + `navDestination()` 分发 →
`ToolHostPage`/`AboutPage` 从 `@Entry` 页面改成 `NavDestination` →
`ToolNavigator` 改调 `ngfNavigationShellFacade.push` →
`main_pages.json` 收缩 → `check-wiring.mjs` 的路由表校验同步改。

**⚠️ 已知框架缺口**：`NGFNavigationParamEnvelope` **没有导出**（全仓只有
`NavigationShellFacade.ets` 自己引用它）。接收方拿到的是 `Object`，
在 ArkTS 里无法结构化地读 `payloadJson`（禁令 `arkts-no-structural-typing`）。
需一并处理：要么回来源仓导出它，要么接收方 `as` 到一个本地同名形状的类。

**执行结果**（已完成）：

- `NGFNavigationParamEnvelope` 的导出缺口已按 §4 **先行补上**并追记 `VENDORED.md`；
- `pages/Index.ets` 建 `NavPathStack` 并写入 `AppStorage['GlobalNavStack']`，
  `Navigation(this.pathStack)` + `navDestination(this.destBuilder)` 分发；
- `ToolHostPage` → `ToolHostView`、`AboutPage` → `AboutView`，都从 `@Entry` 降级为组件；
- `main_pages.json` 收缩为只有 `pages/Index`；
- `core/ToolNavigator.ets` 改调 `ngfNavigationShellFacade.push/pop`；
- `ToolScaffold` 去掉自带的 `NavDestination`——否则会**嵌套 NavDestination**，运行时报错。

**迁移中实测出两个「编译通过但功能失效」的坑，见 §3.3。**

### 3.3 导航迁移里两个「编译通过但功能失效」的坑（实测踩到）

**这两个都不会让编译失败，十道门禁也照过。** 迁到 NavPathStack 时最容易漏：

1. **页面 Router 的调用不会报错，只是不生效。**
   `this.getUIContext().getRouter().back()` 依旧**类型合法、能编译**，
   但页面 Router 的栈在 Navigation 体系下是空的——按下去没有任何反应。
   返回按钮要改用 `ngfNavigationShellFacade.pop()`。
   → 迁移后应全仓 grep `getRouter`，不能只靠编译。

2. **页面生命周期钩子不再覆盖「返回」场景。**
   `onPageShow` / `onPageHide` 是**页面级**事件；destination 出栈时页面没隐藏过，
   它们**不会**触发。首版 `Index.onPageShow` 承担了「返回首页时重读语言」的职责，
   迁移后这个场景会静默失效。
   → 返回场景用 `Navigation.onNavBarStateChange(isVisible)`：导航栏重新可见 == 栈回到根页。
   App 侧现在**两处都保留**（onPageShow 管回前台，onNavBarStateChange 管返回）。

**⚠️ 验证边界**：导航行为（返回键、状态恢复、深链）**编译期查不出来**，
本机也无法真机验证。这部分必须列入真机回归清单，不能因为「编译过了」就算完成。

### 3.4 四个基础能力出口（UI 层收口，app 的固定结构）

`docs/产品定义.md` §3.1 第 56 行把 i18n、深浅双主题列进「框架级功能」。它们在本 app 里的落点是
**四个并列的 UI 层出口**，形状刻意保持一致：

| 出口 | 包住的框架门面 | 提供 |
|---|---|---|
| `ui/ThemeSource.ets` | `ngfThemeManagerFacade` + `ngfColorTokenProviderFacade` | `colorOf(token)`、主题模式读写、`initializeTheme()` |
| `ui/FontScaleSource.ets` | `ngfFontScaleManagerFacade` | `scaled(n)`、档位读写、`initializeFontScale()` |
| `ui/A11y.ets` | `ngfAccessibilityFacade` | `a11yLabel()` / `a11yHint()` / 读屏状态 |
| `ui/LocaleSource.ets` | `ngfI18nManagerFacade` | `currentLocale()`、`resolveText()`、生命周期转发 |

**约束**：每个框架门面在 `entry/` 里**只允许有一个直用点**（就是上表对应的那个文件）。
这条约束是可机检的，现状为零例外：

```
ngfI18nManagerFacade         → ui/LocaleSource.ets
ngfThemeManagerFacade        → ui/ThemeSource.ets
ngfColorTokenProviderFacade  → ui/ThemeSource.ets
ngfFontScaleManagerFacade    → ui/FontScaleSource.ets
ngfAccessibilityFacade       → ui/A11y.ets
```

**为什么这条约束值得维持**：门面签名改动时只需改一处；纯逻辑层永远拿不到门面，
从而保住「可在 Node 里单测」这条底线（`tools/verify/run.mjs --logic`）。

**⚠️ 主题与字体缩放的重渲染陷阱**：`colorOf()` / `scaled()` 都是**运行时取值**，
主题或字号变化时它们不会自己通知 ArkUI。页面必须声明
`@StorageProp(TOOLBOX_DARK_KEY)` 与 `@StorageProp(TOOLBOX_FONT_SCALE_KEY)`
才会重渲染——**这两个字段本身不被使用**，作用就是让 `build()` 重跑。
少了它们，表现为「改了主题/字号界面没反应」，且不报任何错。

### 3.5 框架自带 1303 个字符串键 × 108 个颜色键——注意别撞名

`ngf_framework/src/main/resources/` 自带完整的资源表（base 字符串 1303 键、颜色 108 键），
它会被**合并进 app 的资源**。所以 app 侧定义同名键时会发生「先声明者胜出」的静默覆盖。

实测撞过一次：`about_copyright` 在两侧都有，十道门禁全绿，只有真编译日志里有一行 conflict 告警。
已把 app 侧改名为 `about_app_copyright`。

**给新键命名的建议**：避开框架已有的通用名（`about_` / `glass_` / `text_` / `card_` / `button_` 之类），
工具自己的键继续用工具前缀（现有约定如 `jtk_err_` / `color_` / `codec_`）。
`check-resources.mjs` 现在会机检这条（见 AGENTS.md §3.2）。

### 3.6 `NGFControlStyleTokens`：**部分采纳**（按 §0 记录理由）

框架提供一个控件尺寸常量表（`uiShell/components/NGFControlStyleTokens.ets`，12 行）：
表单控件最小高 40 / 圆角 12 / 字号 14；按钮高 40（dense）与 44（normal）/ 圆角 20 与 22 / 字号 12、13。
**框架内部没用它**——它是给宿主 app 用的设计 Token。

**本仓实测的控件尺寸分布**（全仓统计）：

- `.height(44)` ×15、`.height(40)` ×6 —— 其中 **18 处父元素是 `TextInput`**，只有 3 处是 `Button`
- `.borderRadius(12)` ×81 —— 但**绝大多数是卡片**，不是表单控件
- `.borderRadius(20)` / `(22)` —— **0 处**（按钮圆角那两个常量本仓用不上）

**决定：部分采纳，不做无差别替换**，理由两条：

1. **`borderRadius(12)` 不能整体替换**：那 81 处多为卡片，套上「表单控件圆角」是**语义错误**——
   数值相同不代表含义相同，替换会把「这是表单控件」变成一个假声明。
2. **输入框 44 > `FORM_CONTROL_MIN_HEIGHT`(40)**：常量语义是「**最小**高度」，44 是合法满足。
   改成 40 是**视觉变更**，不该在重构里顺手做掉。

**已采纳的 3 处**（值与元素类型都吻合）：`CodeViewerPage` 按钮 44 → `NORMAL_BUTTON_HEIGHT`；
`QrCodePage` 两个按钮 40 → `DENSE_BUTTON_HEIGHT`。

**若将来要统一控件尺寸**，正确做法是先定本 App 自己的一套尺寸表（而不是直接套框架的），
再整体替换——那是一次独立的外观改动，不是重构的一部分。

## 四、当前 app 的实际使用情况（差距表）

### 4.1 改造前后对照（这张表的变化就是重构本身）

| 门面 / 组件 | 改造前 | 改造后 |
|---|---|---|
| `uiShell` 整层 | **0 处** ❌ | 沉浸式底板 + HdsTabs 页签 + 导航壳层门面 |
| `uiTheme` 整层 | **0 处** ❌ | 颜色 Token + 主题管理 + 字体缩放 |
| `ngfAccessibilityFacade` | **0 处** ❌ | `ui/A11y.ets` |
| `ngfFontScaleManagerFacade` | **0 处** ❌ | `ui/FontScaleSource.ets` |
| `ngfI18nManagerFacade` | 2 个文件直用 | 收敛到 `ui/LocaleSource.ets` 一个出口 |
| `ngfNavigationShellFacade` | **0 处** | `core/ToolNavigator.ets`（页面 Router → NavPathStack） |
| `entry/` 引用 `ngf_framework` | 15 处 / 13 个文件 | **27 个符号 / 29 个文件** |

### 4.2 现在用到的框架符号（全部）

`entry/src` 从 `ngf_framework` 导入的符号，按使用文件数排序：

| 符号 | 文件数 | 说明 |
|---|---|---|
| `NGFColorToken` | 17 | 语义色 Token（页面的 `.fontColor()` / `.backgroundColor()`） |
| `logger` | 8 | 日志 |
| `NGFColorValue` | 2 | 调色板条目（`core/ToolboxPalette`、`ui/ThemeSource`） |
| `ngfNavigationShellFacade` | 2 | 工具页跳转 + 返回 |
| `uiContextManager` | 2 | Ability 上下文绑定 |
| `NGFControlStyleTokens` | 2 | 按钮尺寸（见 §3.6） |
| `ngfAccessibilityFacade` | 1 | `ui/A11y.ets`（四个出口之一） |
| `ngfFontScaleManagerFacade` + `NGFFontScaleLevel` | 1 | `ui/FontScaleSource.ets` |
| `ngfColorTokenProviderFacade` + `ngfThemeManagerFacade` + `NGFThemeMode` | 1 | `ui/ThemeSource.ets` |
| `ngfI18nManagerFacade` | 1 | `ui/LocaleSource.ets` |
| `ngfOverlayManagerFacade` | 1 | `ui/ToolUiKit.ets`（toast） |
| `NGFHdsImmersiveTabs` + `NGFHdsTabItem` | 1 | `pages/Index.ets`（首页页签） |
| `NGFImmersiveTopChromeUnderlay` | 1 | `ui/ToolScaffold.ets`（工具页底板） |
| `ngfImmersiveContentTop` + `NGFImmersiveTopChromeSpec` + `NGFImmersiveTopChromePresetFactory` | 1 | `ui/ImmersiveChrome.ets` |
| `NGFNavigationParamEnvelope` | 1 | `pages/Index.ets`（路由分发读参数） |
| `ngfSettingsStoreFacade` | 1 | `core/ToolStateStore.ets` |
| `ngfMediaPickerFacade` + `FileUtils` | 1 | code-viewer |
| `securityToolkit` + `NGFHashAlgorithm` | 1 | digest |
| `ngfSystemShareFacade` | 1 | qrcode |
| `ngfStarterKernel` / `crashAnalytics` / `ngfScreenKeepAwakeFacade` | 1 | `EntryAbility` |

**四个基础能力各有且仅有一个直用点**（见 §3.4）——这是刻意维持的结构，
不是巧合：门面签名改动只改一处，且纯逻辑层永远拿不到门面。

### 4.3 仍然没用到的框架能力（已评估，均为「不需要」）

| 能力 | 为什么没用 |
|---|---|
| `ngfPageStateStoreFacade` | 页面状态持久化。本 App 每个工具页的生命周期都很短（看一眼就走），状态由自己的 `ToolStateStore` 管草稿，引入它会多一套状态来源。 |
| `ngfDeepLinkFacade` | 深链。App 没有对外分享的 URL 契约，也没有可被外部唤起的页面。 |
| `ngfDragDropManagerFacade` | 拖拽。移动端工具箱没有跨应用拖入的需求。 |
| `ngfHoldingAwarenessFacade` | 握持感知。理论上可做单手布局优化，但当前布局没有为此留设计位；属于**将来可考虑**而非遗漏。 |
| `NGFListPageTemplate` / `NGFDetailPageTemplate` / `NGFFormPageTemplate` | 见 §3.1：形状与工具页不符。**若将来新增纯列表工具（如 HTTP 状态码速查），那件工具应当用它。** |
| `AboutSheetContent` | 本 App 自己实现了关于页（`pages/AboutPage.ets`）。框架那个版本依赖 `app.string.about_*` 资源，采用它会改掉现有文案与版式。 |

## 五、框架侧待修（不自行改 vendored 副本，按 AGENTS.md §4 回来源仓）

1. **`AccessibilityFacade` 没有被导出**：文件在
   `deviceAwareness/facades/AccessibilityFacade.ets`，但 `deviceAwareness/index.ets`
   里没有 `export { ngfAccessibilityFacade, NGFAccessibilityState } from './facades/AccessibilityFacade';`。
   于是 `import { ngfAccessibilityFacade } from 'ngf_framework'` 拿不到——
   无障碍是本项目要用的核心能力，这个缺口必须补。
2. **`uiShell/README.md` 只有 6 行**，且写的是「当前阶段：定义契约，暂不改动业务页面」，
   但同目录 `components/` 下已是完整实现（`NGFPageTemplates` 311 行、
   `NGFImmersiveTopChrome` 228 行、`NGFHdsEffectPresets` 654 行）。
   README 会让人误判「壳还没可用」，建议补一份真实的用法说明。
3. `ngf_framework/` 内有 **97 条编译警告**（HoldingAwareness / SecurityToolkit /
   LocationManager / SensorManager / 生物认证 / 后台任务等门面使用了需要权限或并非全设备支持的 API）。
   本项目未使用这些门面，但 vendored 副本会被一并编译，警告因此出现在本仓构建日志里。

## 六、返工计划（按依赖顺序）——**全部已执行**

1. ~~**本清单**~~ ✅ 已完成（本文档）
2. ~~**基础能力下沉**~~ ✅ 已完成：四个统一出口在 `ui/ThemeSource`、`ui/FontScaleSource`、
   `ui/A11y`、`ui/LocaleSource`（见 §3.4）
3. ~~**主题层替换**~~ ✅ 已完成：自建 `color.json` 只留 1 个键（`start_window_background`，
   被 `module.json5` 引用），494 处取色改走 `colorOf(NGFColorToken.*)`；
   `check-theme-contrast.mjs` 改为审计 `core/ToolboxPalette`
4. ~~**壳层替换**~~ ✅ 已完成：`Index.ets` → `NGFHdsImmersiveTabs`；
   `ToolScaffold` → `NGFImmersiveTopChromeUnderlay`；`ToolNavigator` → `ngfNavigationShellFacade`。
   `NGFPageTemplates` **未采用**，理由见 §3.1
5. ~~**关于页替换**~~ ❌ **不采用**：本 App 已有自己的关于页，框架的 `AboutSheetContent`
   依赖 `app.string.about_*` 资源，采用会改掉现有文案与版式（见 §4.3）
6. ~~**颜色转换工具演示 Token 体系**~~ ✅ 已完成（产品定义稿第 51 行）
7. 全程每批改动后跑 `build.ps1` —— 现在是**十道门禁**，见 `AGENTS.md` §3

**计划已走完。当前剩下的都不是代码问题，而是需要开发者决策的事项**——
真机回归、配色口径、`TOP_SAFE_INSET` 校准、剪贴板按钮取舍。

## 附：HdsTabs 悬浮底栏的完整字段清单（第 103 轮补）

SDK `@hms.hds.hdsBaseComponent.d.ets` 声明的 `HdsTabsFloatingStyle` **一共 10 个字段**：

| 字段 | 作用 | 漏了会怎样 |
|---|---|---|
| `barSideMargin` | 栏与屏幕左右间距 | 栏横向撑满，看不出是浮起的一块 |
| `barBottomMargin` | 栏与 tabs 底部间距 | **栏贴着屏幕底边**，悬浮感消失 |
| `systemMaterialEffect` | 系统材质（毛玻璃） | 栏是一块纯色，没有材质层次 |
| `gradientMask` | 底部渐变遮罩（maskColor/maskHeight） | 滚动内容在栏处被硬切 |
| `barWidth` | 栏宽范围（small/medium/largeWidth） | 栏宽跟随屏幕全宽 |
| `miniBar` | 迷你栏模式 | 无 |
| `adaptToHandedness` | 跟随左右手 | 无 |
| `lightColor` | 光色 | 无 |
| `thermoCtrl` | 温控 | 无 |
| `barOpacity` | 栏不透明度（>0.95 材质形同虚设） | 材质透不出来 |

`HdsTabs` 自身的 22 个属性里，与本主题相关的还有：`barHeight`（栏高）、`animationDuration`（切换动画）、`barBackgroundStyle`（等效于 floating 里的渐变遮罩）、**`onTabBarClick`（切页回调，正解）**、`onSelected`/`onUnselected`。

> 材质参数**不要手写**，用框架的 `NGFHdsEffectPresetFactory.buildSystemMaterialParams(type, level)`，与 `HdsNavigationSupport` 同源，避免顶栏/底栏材质等级漂移。

### ⚠️ 但**别照这张表全填**——来源仓实测过的是 5 个字段

`airwavefootprints/.../MainMenuPage.ets` 的实际配置只有：

```ts
.barMode(BarMode.Fixed)
.barOverlap(true)
.barFloatingStyle({
  adaptToHandedness: true,
  systemMaterialEffect: { materialType: IMMERSIVE, materialLevel: <框架视觉设置> },
  thermoCtrl: true,
  barOpacity: 0.95,
  barBottomMargin: this.bottomInsetVp   // TYPE_NAVIGATION_INDICATOR 实测高度
})
.scrollable(true)
.onChange((index) => { ... })
```

**关键两条**（本仓都踩过）：

1. **不要设 `barHeight`** —— 系统默认高度才是设计值；自己撑高会破坏沉浸比例。
2. **`barBottomMargin` 用动态值**（手势条实测高度，本机 27.85vp），不要写死。
   写死 16 会让栏压在手势条上或离底太远；写 0 则贴底。

其余字段（`barWidth` / `barSideMargin` / `miniBar` / `lightColor`）留给需要时再调，
**不要为了「填满接口」而加**——多写一个就可能多一处与设计不符。