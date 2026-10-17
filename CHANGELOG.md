# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 的组织方式，
版本号以 `AppScope/app.json5` 为唯一源。

## [未发布] 第二阶段：开发功能 50 项 + 全量双语 / 无障碍 / 关怀模式 + 动效

> 本节数字是**第 109 轮快照**，权威来源始终是十道门禁（见 `AGENTS.md` §3.1 / §3.2）。
> 想知道当前值就跑门禁，不要引用本节数字做判断。

### Added — 65 件新工具（工具总数 81，按四分类）

规划 50 项全部落地，另做 18 件超额工具。分类分布：**文本与数据 38 · 编解码与计算 26 · 网络 12 · 文件与生成 5**。

**文本与数据（38）**

MD 预览、CSV 与 JSON 互转、Base64 图片预览、正则替换预览、Shell 速查、更新日志生成、
JSON 转接口文档、快捷键速查、Git 速查、十六进制转储、行号添加器、文本换行、字符频率、
表格生成、ASCII 对照表、键盘符号速查、实体速查、链接检查、Cron 速查、文档目录生成、
代码压缩预览、ASCII 分隔线、文本哈希校验、占位文本生成、HTML 实体、文本行工具、
命名风格转换、正则速查、SQL 格式化、YAML 解析、TOML 解析、表单解析、JSON 路径取值、
URL 编解码、正则测试、JSON 工具、Cron 解析、文本 Diff

**编解码与计算（26）**

单位换算、浮点位分解、位运算器、色板生成、对比度检查、时区会议时间、迭代计算、
版本号解析、存储单位速查、两色混合、字节序演示、日期差计算、色相微调、JWT 构建、
Epoch 对照表、百分比计算、校验和、HMAC 计算、时间戳、编解码套件、摘要计算、JWT 解码、
进制转换、日期计算、UUID 与随机密码、颜色转换

**网络（12）**

HTTP 命令生成、Cookie 头解析、HTTP 方法速查、UA 解析、URL 解析器、MIME 速查、
端口速查、HTTP 头速查、HTTP 状态码、IP/CIDR 计算器、子网计算、端口测试

**文件与生成（5）**

假数据生成、密码强度评估、UUID 批量生成、二维码生成、代码查看

> 联网的只有「端口测试」一件，且在其页面内明示——隐私/权限红线未变。

### Added — 双语（81/81 件工具，剩余 0 处）

App 内不再有单语用户可见文案。按数据性质分三条路径，不混用：

- **内容数据**双语化：数据表工具的 name / meaning / cause / example 等列改为 `NGFLocalizedText`；
- **固定标签**走资源键：base / zh_CN / en_US 三份 `string.json` 同步补齐；
- **生成语料**行内豁免：lorem-ipsum 词库、mock-data 姓名表等加 `// i18n-corpus-data`，
  豁免点连 file:line 全量打印——豁免必须可审计。

例：`json2doc` 生成的 Markdown 列名跟随语言（`jsonToDoc(input, english)`）。

### Added — 无障碍（可点 Text 100/100 · Toggle 16/16）

全部可点 `Text` 与 `Toggle` 都有 `accessibilityText`：复制类统一走 `copied_common`，
模式切换/清空类按自身语义（chip 用自身标签、布尔开关用三元双键、组合文本用拼接表达式）。
数据列表行由容器聚合朗读。判据已做成可复核矩阵，不是抽检。

### Added — 关怀模式（字号 784/784 走 `scaled()`）

工具页 750 处 + 壳页面 34 处 `fontSize` 全部经 `scaled()`，零硬编码字号；
用户调大字体时 81 件工具页与壳层一致响应。

### Added — 动效

- 结果出现：250ms 淡入（27 件有结果区的工具）；
- 复制反馈：150ms + 1.08 缩放（23 件有复制按钮的工具）；
- 页签按压反馈 scale 0.92 / 180ms；页签切换 `animationDuration(250)`。

> 只读速查表（无结果区、无复制按钮）不强制动效——不适用即不做，不为凑数加。

### Changed — 首页底栏对齐框架原版（悬浮胶囊）

首版只写了 `barOverlap(true)`，底部是**贴着屏幕边缘的一行裸文字**。补齐框架的浮动栏配置：

- `.barFloatingStyle(...)` 让栏浮起（圆角 + 系统材质 IMMERSIVE）；
- `barBottomMargin` 取 `TYPE_NAVIGATION_INDICATOR` 的**实测高度**（本机 27.85vp），不写死；
- **不设 `barHeight`** —— 系统默认高度才是设计值，自己撑高会破坏沉浸比例；
- 5 个页签补 `SymbolGlyph` 图标（选中 24/加粗主色，未选 22/次要色）+ 弹跳动效；
- 切页改用框架的 `onTabBarClick`，不再在 `onTouch` 里手搓（后者会吞掉点击）；
- 内容底部留白 76 → 104，滚到底不再被浮动栏压住。

材质参数走框架的 `NGFHdsEffectPresetFactory.buildSystemMaterialParams()`，与顶栏同源。

### Fixed — 真机回归发现的缺陷

- **首页页签选中态白字配浅底，几乎看不见**：选中色原用 `ON_PRIMARY`（白色），
  而底栏本身没有主色背景。改为 `PRIMARY`。**十道门禁全绿也查不出的那种。**
- **13 个工具页显示 `[object Object]`**：`Text($r('app.string.x') + ': ' + n)` ——
  `$r()` 返回 `Resource` 对象，直接拼接得到 `[object Object]`。统一包 `ToolUiKit.text()`（17 处）。
  涉及 char-frequency / cookie-header / form-decode / hex-dump / http-method / img-base64 /
  json2doc / md-link-check / shell-cheatsheet / sprint-calc / url-parser / uuid-batch / word-wrap。

### Fixed — 门禁体系自身

- **`check-resources.mjs` 是一条「不可能失败」的门禁**：它报问题、输出正确，
  但**所有失败路径都没有 `process.exit(1)`**，退出码恒为 0，在十道门禁里从未失败过。
  修复后立即抓到两个此前被放过的真问题（Index 的硬编码渐变色、4 个专名键误报）。
  同类缺陷此前已在 `scan-comments.mjs` 上出现过一次。
- **`check-i18n.mjs` 新增第三种豁免标记** `i18n-corpus-data`（生成器语料），
  并把全部豁免点连 file:line 打印，使「豁免」可审计而不是静默放过。
- 变异验证脚本 `mutation-check.mjs` 扩到 **17 条**，全部通过（17/0），
  用于区分「检查通过」和「检查没跑」。

### Changed — 测试

- 单测 **1083 用例 / 0 失败**，93 个测试文件；83 个纯逻辑模块**全部**有测试 import（零盲区）。
- 六件代表性工具做了**独立抽查**（不经测试框架、直接 Node 跑算法对照手算）：
  byte-split 字节序、date-diff 工作日、color-blend 中点、radix-convert、hue-shift 色相环回，全部命中。
- `ToolsCatalogTest` 的单测计数随工具增长同步到 81。

### 待办（第二阶段）

- **真机回归 49 件**：已完成 40 件，0 缺陷，剩余 9 件（清单见 `docs/真机回归批次.md`）；
- 需要输入才能出结果的工具，自动化只能验到首屏——**功能逻辑由 1083 单测覆盖**，
  真机侧待人工补验「输入 → 结果」路径；
- 版本号：建议 `0.1.0 → 0.2.0`（versionCode 同步 +1），由开发者定夺。


## [未发布] 第一阶段：壳层/主题层重构（对齐 NGF 框架既有能力）

首版自建了一套壳层（首页网格 + ToolScaffold + 页面 Router）与主题层（两份 `element/color.json`），
把框架已做好的 HdsTabs、沉浸式顶栏、颜色 Token 体系、无障碍与字体缩放门面全部丢掉了。
本次整体迁回框架能力，并按 `docs/产品定义.md` §3.1 的分层落位。

### 壳层
- 首页改用 `NGFHdsImmersiveTabs`（HdsTabs + IMMERSIVE 材质 + 浮动底栏），页签 = 收藏与最近 + 各工具分类
- 工具页改用 `NGFImmersiveTopChromeUnderlay` 沉浸式底板（16 件工具一次性生效，因改造在 `ToolScaffold` 层）
- 导航从页面 Router 迁到 `ngfNavigationShellFacade` + `NavPathStack`；
  `ToolHostPage`/`AboutPage` 由 `@Entry` 页面降级为 `NavDestination`，`main_pages.json` 只剩 `pages/Index`

### 主题
- 删除自建的 13 个颜色键（两份 `color.json` 各留 `start_window_background`，被 `module.json5` 引用）
- 改走 uiTheme 的 `ColorTokenProviderFacade`：`core/ToolboxPalette.ets` 为唯一色表，
  494 处 `$r('app.color.*')` 全部改为 `colorOf(NGFColorToken.*)`
- `check-theme-contrast.mjs` 改为审计调色板（30 组配色），与界面取色**同一份数据**

### 基础能力
- 关怀模式：308 处硬编码字号改为 `scaled(n)`，接 `FontScaleManagerFacade`
- 无障碍：补齐纯色块的可点标签（`accessibilityText/Level/Group`）
- 主题与字体缩放均通过 AppStorage 键 + `@StorageProp` 触发重渲染（运行时取值不会自己通知 ArkUI）

### 框架先行改动（需回来源仓，见 `ngf_framework/VENDORED.md`）
- `deviceAwareness` 补 `AccessibilityFacade` 导出
- `NGFColorToken` 补 5 个语义色（error_container / warning / warning_container / success）
- `NGFNavigationParamEnvelope` 补 `export`

### 待办（发布决策）
- 真机回归：导航行为（返回、状态恢复、深链）、沉浸式底板顶部避让值
- 配色口径：框架调色板 vs 工具箱蓝，两者目前同屏并存

## [Unreleased]

### Fixed — 真编译（第 22 轮）

- 新增第十道门禁 `tools/verify/build.ps1`：跑一次真正的 ArkTS 编译。
  起因：九道 Node 门禁全绿，真编译却有 **75 ERROR + 107 WARN**。
  Node 门禁做的是**类型剥离**，从不做类型检查，也不认识 ArkUI DSL。
- 修完 75 个 ERROR：`$r()` 返回 Resource 却传给 string 形参（19）、
  `WrappedBuilder` 被误当 import（3）、缺 import（14）、`JsonErrorCode` 少了 3 个成员（6）、
  `TextSelectableMode.SELECTABLE_UNFOCUSED` 拼错（6）、`@Builder` 体里写语句（3）、
  `content` 未用 `@BuilderParam`（1）等。
  其中 `ToolScaffold`/`ToolPageRegistry`/`ToolHostPage` 的动态构建器派发改用
  `@BuilderParam` + `wrapBuilder` + `WrappedBuilder.builder()`，是真正的机制修复。
- `entry/` 警告 11 → 3（剩下的 2 条是 API「并非所有设备支持」的能力提示，
  1 条是读剪贴板需要 `READ_PASTEBOARD` 权限——与「只允许 INTERNET」的红线冲突，需开发者决策）。
  其余 97 条在 `ngf_framework/` 副本内，按 §4 纪律应回来源仓处理。
- `check-pages.mjs` 的「@Builder 漏括号」规则补了例外：`@BuilderParam x = this.y;`
  这一行的不带括号引用是**正确的**，并已用「故意漏括号」自测确认规则仍然会红。

### Added — 功能开发第一阶段

**NGF 框架正式接线**

- `GlobalContext.ets`：工具箱全局上下文持有者（只暴露 filesDir，依赖面刻意收窄）。
- `application/ToolboxApplication.ets`：应用层初始化门面（登记工具清单 + 加载用户状态）。
- `EntryAbility.ets`：完成 `bindAbilityContext → bootstrap → 屏幕常亮/崩溃日志`
  → 工具清单 → 主题/i18n 门面 的接线顺序；`onConfigurationUpdate` 转发系统深浅色与语言变化。
  工具箱**跟随系统**深浅色（不强制深色）。

**工具注册表与正式首页**

- `core/ToolModel.ets` / `core/ToolRegistry.ets`：工具元数据与注册表（注册、查询、
  分类分组、搜索打分）。首页不认识任何一件具体工具——新增工具不改首页。
- `ui/ToolPageRegistry.ets`：工具 id → 页面构建器（与纯数据元数据分层）。
- `ui/ToolScaffold.ets`：工具页统一模板（标题/收藏/联网明示/滚动/「做不到什么」帮助区）。
- `ui/ToolUiKit.ets`：复制+提示 / 剪贴板 / 字符串资源解析的统一出口。
- `pages/Index.ets`：正式首页（搜索 + 收藏 + 最近使用 + 分类自适应网格）。
- `pages/ToolHostPage.ets`：所有工具共用的宿主路由页，未实现工具显示「建设中」。
- `core/ToolStateModel.ets` / `core/ToolStateStore.ets`：收藏、最近使用、输入草稿的
  本地持久化（NGF data 层 Preferences）。
- `core/ToolGridLayout.ets`：首页网格列数的纯函数计算（可单测）。
- 深浅色主题色 `resources/base/element/color.json` + `resources/dark/element/color.json`。

**首发 16 件工具全部可用**（含纯逻辑、页面与单测；不再有「建设中」占位）

正则测试、JSON 工具、时间戳、编解码套件、摘要计算、JWT 解码、Cron 解析、进制转换、
日期计算、UUID 与随机密码、子网计算、文本 Diff、颜色转换、端口测试、二维码生成、代码查看。

其中端口测试是全 App **唯一联网**的功能（页内明示，且能在离线阶段判定的无效输入
一个包都不发出去）；二维码生成不做图片导出；代码查看只读、经系统选择器打开且不申请存储权限。

**关于页（NGF 专区）**

框架能力清单（只列本 App 真的用到的层）、仓库二维码、隐私承诺（可逐条对着代码核对）、
同框架作品与反馈渠道。入口在首页标题右侧。
项目地址、反馈链接、版本号格式化、链接合法性检查都抽在 `about/AppInfo.ets`（纯逻辑 + 单测），
因此任何一条对外地址写错都会在测试里暴露，而不是等用户点了没反应。

**本机验证工具链 `tools/verify/`（新增）**

本机无 DevEco/hvigor 且 CI 只构建不跑单测，故新增基于 Node 类型剥离的验证器，
直接执行 `entry/src/test` 下的同一份单测：

- `run.mjs`：全量单测（573 用例）与 `--logic` 纯逻辑层洁净度检查（26 个模块）。
- `gen-test-entry.mjs`：生成 hypium 总入口 `List.test.ets`（hypium 无自动发现机制，
  漏登记 = 测试在真机上从不执行）。
- `check-pages.mjs`：页面/组件文件静态结构检查（组件名拼错、`@Builder` 漏括号、
  括号不配对、`build()` 提前 return、调用不存在的方法、`$r()` 参数非字面量）。
- `check-wiring.mjs`：接线一致性（元数据清单 ↔ 页面注册表 ↔ 工具目录 ↔ 单测 ↔ hypium 总入口
  ↔ `main_pages.json` 路由表），含「构建器名与导入路径能否对上真实导出」的双向校验，
  以及「`@Entry` 页面是否登记进路由表」的双向核对（漏登记在真机上打开会失败且编译期不报）。
- `scan-comments.mjs`：块注释提前闭合扫描（注释里的「星号 + 斜杠」组合会提前结束注释）。
- `check-resources.mjs`：资源引用与多语言一致性（代码引用的 `$r()` 键是否存在、
  `base`/`zh_CN`/`en_US` 三份表是否对齐、暗色主题色是否补齐）。
  它把「资源键写错 → 构建失败」这件事从「只有 CI 能发现」变成本机可查。
- `check-theme-contrast.mjs`：主题对比度门禁，用本 App 自己的 WCAG 实现审计两种主题的 30 组配色。
  刻意复用 `ColorConvert.ets` 而非另写一份公式——两份公式迟早漂移。
- `cross-verify-hash.mjs`：摘要算法与 Node 内置 crypto 对拍（56 组，含分组填充边界）。

**文档与规则**

- `AGENTS.md` §3.1：验证工具链用法与边界。
- `.agent-rules/project-rules.md`：新增 PR-009（纯逻辑必须本机验证）、
  PR-010（类型别名须单独 import）、PR-011（页面结构检查）、
  PR-012（接线一致性）、PR-013（资源引用必须字面量）、PR-014（注释闭合安全）。
- `docs/开发交接.md`：重写为功能阶段交接（含已知边界与风险）。

### Added — 双语（第三步：占位符路线定案 + 覆盖面门禁）

- 占位符参数定案为 `ToolUiKit.stringOf($r('app.string.x'), [args…])`：键保持**字面量**
  （构建期可改写、`check-resources.mjs` 可核对），代入交给框架已有的
  `resolveStringWithArgs` → `resourceManager.getStringSync(resource.id, ...args)`。
  不采用 `$r('app.string.x', args…)`——它把代入交给 ArkUI 渲染器，本机无法构建验证；
  已有可复用且有旁证的实现时没必要冒险。`ToolUiKit.stringOf` 入参放宽为 `string | Resource`。
- `radix-convert` 完成端到端改造（纯逻辑错误码 + 页面全部走资源键），成为样板；
  其后 `digest`、`code-viewer`、`text-diff`、`subnet-calc`、`color-convert`、`date-calc`、
  `uuid-password`、`timestamp`、`qrcode`、`codec-suite`、`jwt-decoder`、`cron-parser`、
  `json-toolkit`、`port-tester`、`regex-tester` 依次照此改造完成（共 16 件，全部）。
- 新增 `tools/verify/check-i18n.mjs`：打印每件工具剩余的**用户可见中文串**数量
  （口径：含中文的字符串字面量，排除注释与 `logger.*` 参数），
  并对登记在 `COMPLETED_TOOLS` 里的工具做**防回退**断言。
  漏翻译是不报错、不崩溃的安静失败，八道原有门禁一道都看不出来，所以需要它。
  当前进度 16/16，合计剩余 0 处——第三步（双语）已全部收尾，`check-i18n.mjs` 无残留。

### Added — 双语（第三步样板：纯逻辑改用错误码）

- `radix-convert` 作为样板完成改造：纯逻辑新增 `RadixFailureCode` + `RadixFailure { code, args }`，
  不再返回中文句子；新增 UI 层 `RadixConvertMessages.ets` 做「码 → 文案」映射；
  三份资源表加 5 个 `err_radix_*` 键；单测改为断言**错误码与参数**而不是文案。
  用 `RadixFailure.none()` 兜住成功路径，使 `failure` 字段永不为 null，传递上游失败时不必判空。
- `run.mjs --logic` 升级：原先只做「模块能否加载」的冒烟，而调用 `$r()` 的文件
  **照样能加载**（`$r` 只在函数体里），于是检查结果是一盏假的绿灯。
  现在改为**静态断言洁净度**：纯逻辑文件里出现 `$r()` 或 ArkUI 装饰器直接判失败；
  依赖框架/系统能力（有替身承接）的模块如实报出条数与原因，让「本机可验证」这句话可核对。
  这条新检查立刻抓出 `core/ToolStateStore.ets` 是框架依赖（它本来就该是，此前只是被算成了纯逻辑）。

### Added — 双语（第二步：外壳文案）

- `base` / `zh_CN` / `en_US` 三份 `string.json` 各 40 个键，覆盖首页、`ToolScaffold`、
  工具宿主页、`ToolUiKit` 与关于页的全部固定文案（小标题、按钮、空态提示、联网明示、
  「做不到什么」帮助区、页脚、无障碍标签）。
- 关于页的内容数据（框架能力说明、隐私承诺、链接名）改用 `NGFLocalizedText`，
  由页面按 locale 取用；固定标签走 `$r()`。分工规则：能进纯数据层的带双语，
  只有 UI 自己的话才用资源键（纯数据层 import ArkUI 会让本机单测失效）。
- `check-resources.mjs`：漏翻译从「提示」升级为「判失败」，只有显式登记在
  `SAME_IN_BOTH_LANGUAGES` 白名单里的键允许中英相同（目前只有版权行）。
  缺翻译是安静的失败，不变成红灯等于没检查。

### Added — 双语（第一步：工具元数据）

- `NGFLocalizedText`：成对持有中英文，`forLocale` 双向回退（缺哪一侧就用另一侧）。
- 16 件工具的英文名/说明/边界全部补齐（48 处），清单抽成导出的 `builtinTools()`，
  启动登记与单测共用同一份数据（此前 16 行 `registry.register(...)` 与单测各查各的）。
- 搜索改为同时匹配中英两侧并取较高分：中文用户敲 `json`、英文用户敲「时间戳」都能搜到。
  此前英文环境下搜 `Timestamp` 搜不到，这个缺陷随之关闭。
- 分类名（文本与数据 / Text & Data 等）双语。
- `ui/LocaleSource.ets`：当前语言的唯一出口，语言由 UI 层读出来后作为参数传给纯逻辑层。
- `ToolsCatalogTest`：断言 16 件工具的英文都写全了。缺英文会**安静回退中文**，
  不报错不崩溃，靠人工检查必漏，所以必须由测试兜住。
  顺带钉住 id/order 唯一、分类合法、以及「联网工具只有一件」（隐私红线哨兵）。

### Fixed

- **`qrcode` 的 `normalizeUrl('')` 被改成返回 `'none'`**：批量把「函数末尾的 `return '';`」
  换成返回码时，`.replace()` 只替换了**第一处**，而第一处落在 `normalizeUrl` 里。
  单测立刻抓到（期望 `""`，实际 `"none"`）。教训：按内容做全局替换时，
  如果同一个字面量在多个函数里出现，必须带上下文或改用带函数名的锚点。
- **`qrcode` 的结果对象回传了「已翻译好的显示名」**：`kindLabel` 就是请求里 kind 的显示名，
  页面本来就知道 kind。去掉后纯逻辑不再产出文案，页面也少了一个不再被读的 @State 字段。

- **`timestamp` 里「秒/毫秒向下取整」写了两遍**：页面上一处、纯逻辑里一处
  （`millisToSeconds`）。同一件事写两遍，将来改成四舍五入就会两边不一致。
  页面改为统一调用纯逻辑的实现。
- **`timestamp` 的位数上限硬编码为 16**：它同时出现在长度检查与
  「最多 N 位」的文案里。提成 `TIMESTAMP_MAX_DIGITS` 常量，两处共用。

- **`uuid-password` 拿显示文案当逻辑键**：`toggleClass(label, value)` 靠
  `if (label === '小写 abc')` 找字段。中文单语时看不出问题，但标签一旦被翻译，
  开关就会和字段失联。已改为 `FIELD_*` 常量。
- **`uuid-password` 一处失败分支不可达**：`TOO_SHORT_FOR_POOLS`（长度 < 类别数）
  在 `PASSWORD_MIN_LENGTH = 4`、最多 4 个类别的前提下永远触发不了。
  保留为**不变式守卫**并写明原因（谁把下限改小到 3，没有它就会静默漏掉一个字符类别），
  测试改为断言真正会发生的 `LENGTH_RANGE` 并注明该守卫不可达。
- **`check-i18n.mjs` 的豁免机制只有一个硬编码理由**：改为**豁免分组表**
  （`EXEMPTION_MARKERS`），每组必须写明理由，跑完分组打印全部豁免点。
  新增「开发者可见的契约错误」一组，用于 `throw new Error(...)` 这类
  只在开发期出现、用户永远看不到的消息。

- **`check-i18n.mjs` 无法表达「这是输入语法不是文案」**：date-calc 接受
  `2024年2月29日` 这种输入，源码里的 '年'/'月'/'日' 是**解析器语法**，
  与「硬编码中文文案」字符层面一样却被误报。新增 `// i18n-parser-literal` 行内标记，
  并把全部豁免点连同 file:line 打印出来供复核——**豁免必须可审计**。
- **`check-i18n.mjs` 的注释剥离会改变行号**：块注释被整体替换成一个空格，
  其内部换行随之消失，导致「按行豁免」的行号对不上。改为用等量换行补回，
  使剥离前后行号一致。

- **`subnet-calc` 的前缀常识提示从未显示**：`prefixRemark` 有实现、有单测，
  但页面从来没调用它——用户永远看不到「这是最常见的局域网规格」这类提示。
  现已接进「无注意事项时显示」的分支，并做成二选一避免与注意事项重复。
- **`check-i18n.mjs` 把成对的双语字面量误报为未翻译**：`l10n('回环地址', 'Loopback')`
  与「硬编码一句中文」在字符层面一样，于是已完成的工具被判「回退」。
  改为先做**结构识别**（只认 `l10n(...)` / `new NGFLocalizedText(...)` 且中文后紧跟
  非空无中文的译文），再统计。判据刻意收窄——放宽门禁等于关掉门禁。

- **`check-i18n.mjs` 的 logger 排除判据过窄**：它用回溯式正则判断「这个字符串是不是
  logger 的参数」，只要参数里有**嵌套括号**（例如 `String(doc.totalLines)`）就匹配不上，
  于是日志文案被算成用户可见文案（报出一次假问题）。改为**按行**判断，简单且不受括号影响。

- **`check-resources.mjs` 漏掉带参数的资源引用**：正则要求键后面紧跟右括号，
  于是 `$r('app.string.x', arg)` 这种带占位符的写法**完全扫不到**，
  还会反过来把用到的键报成「已定义但未引用」（假问题）。已改为只要求字面量键。

- **关于页首帧把「还没读完」显示成「读取失败」**：版本号是异步读的，
  原先只用「文案是否为空」判断失败，于是刚进页面就闪一下「读取失败」。
  改为用 `versionFailed` 标志区分「读取中 / 已读到 / 读失败」三态。
  这是 `check-resources.mjs` 报出「`about_reading_version` 未被引用」时顺出来的。
- **`check-pages.mjs` 里有一段死代码**：「排除 `new X(` 构造调用」的正则永远匹配不到，
  因为 16 字符的 look-behind 窗口恰好把正则已经消费掉的那个空格排除在外。
  同一函数里还有一处「压行白算了」（算出 `flat` 却对 `stripped` 执行），
  导致跨行 import 一律解析不到、已导入的名字被误报成未知组件。两处都已修正。
- **`check-wiring.mjs` 会被自己的重构弄坏**：元数据登记从「16 行 `registry.register(...)`」
  收敛成「遍历 `builtinTools()` 数组」后，基于「找 register 调用」的抠法一条也匹配不到，
  32 个工具目录全被判成未登记。改为直接 import `builtinTools()` 问运行时真相——
  判据不能建立在「容易被重构改掉的写法」上。
- **`check-resources.mjs` 会扫注释里的示例**：文档注释中写的 `$r('app.string.…')`
  被当成真实引用而报错。改为先剥注释再扫（假问题比没有问题更糟）。

- **浅色主题每次启动先闪一下黑屏**：`start_window_background` 在浅色表里是 `#101814`（近黑），
  与浅色页面底色 `#F1F3F5` 相差极大，导致「黑屏 → 白页」的突变。
  改为与页面底色一致（浅色 `#F1F3F5`；深色表原本缺这个键，补上 `#101418`）。
  这是 `check-resources.mjs` 上线后报出的第一个问题。
- **浅色主题 4 个语义色不满足 WCAG AA 4.5:1**：次文本 4.09、错误色 3.75、
  成功色 4.12、警告色 4.33。按「保持色相、只降明度」微调至达标：
  `#6B7787 → #636E7E`、`#D94838 → #C93726`、`#1F8A4C → #1D8147`、`#A8620A → #A45E0A`。
  现两种主题共 30 组配色全部 ≥4.5:1（深色主题原本即全部达标，最低 5.67）。