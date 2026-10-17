# AGENTS

本文件是 **NGF 开发者工具箱（ngf-toolbox）** 仓库的统一代理工作规范。任何 Agent（桌面端 / 沙箱 / 其他）在本仓动手前先读本文件与 `.agent-rules/project-rules.md` 的全部 active 条目。

## 0. 动手前先读框架能力清单（血泪教训）

**`docs/NGF框架能力清单.md`** 是必读，优先级高于本文件其余部分。

原因：首版开发时 Agent 只按符号 grep 框架代码，从没盘点过「框架有哪些层、每层提供什么」，
于是手搓了一套壳层（`Index.ets` 网格 + `ToolScaffold`）和主题层（自建两份 `color.json`），
把框架**已经做好并实测过**的沉浸式顶栏、HdsTabs、页面模板、颜色 Token 体系、
无障碍门面、字体缩放（关怀模式）全部丢掉了——而 `docs/产品定义.md` §3.1 第 56 行
明确写了「壳导航（core + uiShell）」「深浅双主题（uiTheme）」。

**规则**：新增任何 UI/主题/无障碍/字体相关的代码前，先在清单里确认框架有没有现成的。
有就用；没有或确实不适用，在清单里记一条「为什么不用」，再自己写。

**已记录的一处「不适用」**：`NGFHdsImmersiveTabs`（HdsTabs）**不用于渲染内容**。
真机实测它只画出页签条、`TabContent` 里什么都不渲染（详见 `ngf_framework/VENDORED.md`）。
首页改为自绘分类页签条。**教训**：这个组件在框架里没有任何使用示例，
是「框架提供了 API」和「API 在真机上能用」之间的差距——
而十道门禁**一道都查不出**这种情况。

**已记录的第二处「用了但没配对」**：HdsTabs 的悬浮底栏。`barOverlap(true)` 只是「栏压在内容之上」，栏自身仍是贴屏幕底边的一条**通栏**；真正让它浮起、带圆角与系统材质背景的是 `.barFloatingStyle(...)`。

**配法照来源仓 `MainMenuPage` 抄，不要自己发挥**（它是实测过的）：
`adaptToHandedness` / `systemMaterialEffect` / `thermoCtrl` / `barOpacity: 0.95` / `barBottomMargin` —— **就这 5 个**。

两条错法本仓都踩过：
1. **不写 `barFloatingStyle`** → 底部是贴边裸文字（门禁全绿也查不出）。
2. **自己加 `barHeight`、把 `barBottomMargin` 写死 16** → 栏被撑高、还不躲手势条。
   正解：**不设 `barHeight`**（用系统默认高度），`barBottomMargin` 取
   `TYPE_NAVIGATION_INDICATOR` 的实测高度——本仓已有 `ui/WindowChrome.ets` 的 `loadDynamicInsets()`，
   复用它的 `bottom` 回参即可（本机实测 27.85vp；写死 16 会压在手势条上）。

**同源的第二坑**：自定义 `.tabBar(@Builder)` 只是**展示内容**，HdsTabs 不会自动把它和切换绑定；
而在 `.tabBar()` 内容上挂 `onTouch`（做按压反馈要挂）会**消费掉点击**，页签彻底点不动。
正解是给 HdsTabs 挂 **`onTabBarClick((index) => this.tabsController.changeIndex(index))`**——
这是 `HdsTabsAttribute` 自带属性（22 个之一），比在 `onTouch` 里手搓干净得多，且按压反馈可以独立保留。

## 1. 仓库定位

- 本仓是一个独立的 HarmonyOS 应用工程：`entry/` 是应用（NGF 开发者工具箱），`ngf_framework/` 是 vendored 的 NGF 框架副本（见 `ngf_framework/VENDORED.md`）。
- 本 App 是 **NGF 框架的官方样板应用**：代码本身就是给框架使用者看的教学材料，注释与分层纪律按「给陌生开发者读」的标准执行。
- 产品定义（定位、工具清单、交互规范、质量门禁）以 `docs/产品定义.md` 为准；开发交接状态以 `docs/开发交接.md` 为准。两者冲突时先问开发者，不要自行裁决。

## 2. 硬性规则

- 文件读写一律显式 UTF-8。
- ArkTS 规范从严：禁止 `any`/`unknown`、禁止模板字面量（用字符串拼接）、显式类型标注、异常捕获必须处理。细则沿用 NGF 来源仓（airwavefootprints）的 `.rules/skill-arkts-standards.md`，本仓不复述。
- 构建验证走 CI（`.github/workflows/build.yml`）；本机若装了 DevEco，**交活前必须本地跑一次真编译**（`tools/verify/build.ps1`，见 §3.2）。
  注意 §2 与 §3.2 不冲突：这里说的「不自动跑」是指**每次改文件都触发构建**没有意义，
  而**交活前**这一次是不能省的——九道 Node 门禁不查类型。
- 但**纯逻辑必须在本机跑通测试再交**：本仓自带 `tools/verify/`（见 §3.1），它用 Node 直接执行 `entry/src/test` 里的真实单测，不需要 DevEco。CI 只做构建，不跑单测，所以「本地跳过验证等 CI」等于没人验证算法正确性。
- 对侵入性/高风险修改，先在同目录做 `*.bak` 备份再动手。
- **改文件前先确认换行符**：本仓部分文件是 **CRLF**（`build-profile.json5`、
  `ngf_framework/**` 全是）。用带 `\n` 的多行锚点去 `String.replace` 会**静默失败**——
  不报错、不抛异常，只是什么都没改。已踩过两次（`build-profile.json5` 的 signingConfig、
  `NGFColorToken` 的枚举成员）。
  规则：**多行锚点一律先读原文确认 `\r\n`**，或者改用单行锚点；
  并且**替换后必须验证结果**（`includes()` 复核），不要替换完就打印成功。
- **不要在其它文档里复制门禁命令与计数**——只指向本文件的 §3.1/§3.2。
  实测：`docs/开发交接.md` 里有一份手抄的命令清单，写着「单测 560 用例 / 页面结构 52 文件」，
  而实际是 620 / 76；**还漏掉了 4 道门禁**，其中 `check-wiring` 那条漏了 `--import`（照抄会直接失败）。
  同一份文档的验收口径更写着「**四道**本机门禁全绿」——而真实门槛是十道。
  一个照它验收的人会跑四道就以为过关。**复制出来的清单必然腐烂，指向唯一来源。**
  **同一个坑第二次踩**：`docs/验收报告.md` 里手抄了门禁的实测数字
  （单测用例数、扫描文件数、资源键数、变异条数、HAP 大小）。
  第 30 轮写的报告到第 39 轮已有 **7 处全部失效**——而这份报告正是交给开发者的验收依据。
  规则同样适用：**报告里保留数字时必须显式标注「这是快照，权威来源是门禁」**，
  否则读者会把它当实时数据用。
- **按标题分块重排文档时，第一个标题之前的内容不在任何块里。**
  实测：重排 `docs/NGF框架能力清单.md` 的章节顺序，从「第一个 H2」开始切块，
  把**文件标题与引言（整整 10 行）丢掉了**——而该文件当时**未被 git 跟踪、也没有 `.bak`**，
  只能凭记忆重写。做这类操作前先复一份 `.bak`；切完核对总行数。
  （同理：任何「按标记切块再重排」的脚本，都要显式处理**首个标记之前的前导内容**。）
- **别用 `[\\s\\S]*?\\` 去跨行匹配 import 块**：惰性量词会从**更早**的一个
  `import {` 开始匹配、一路跨到目标 `} from '...';`，把中间所有 import 一起吞掉。
  实测踩过两次：一次把 `NGFColorToken` 插进了 `@kit.NetworkKit` 的 import，
  一次把整行 `import { colorOf } from '../ui/ThemeSource'` 吞没了。
  规则：**按行号定位、或改用单行锚点**（`import { logger } from 'ngf_framework';` 这种）。
- **隐私红线**：本 App 零遥测、零统计、零账号；不得引入任何数据收集 SDK 或自建上报。唯一网络用途是「端口测试」工具连接用户自己输入的主机，且必须在该工具页面内明示。
- **权限红线**：`entry/src/main/module.json5` 只允许 `ohos.permission.INTERNET` 一项；新增任何权限必须先经开发者确认并记入 `.agent-rules/project-rules.md`。
- **免费红线**：本 App 完全免费，不得加入内购、广告、付费解锁相关代码或配置。

## 3. 工具开发约定

- 每个工具一个独立模块目录：`entry/src/main/ets/tools/<toolId>/`，内含页面组件与纯逻辑文件；逻辑与 UI 分离，纯逻辑必须有单元测试（`entry/src/test/`）。
- 工具只能通过**工具注册表**接入首页（注册表在功能阶段建立，见开发交接），禁止在首页硬编码跳转到具体工具实现细节之外的耦合。
- 工具的输入/输出交互遵循产品定义稿的统一模板（输入区 → 处理 → 输出区 → 复制/历史/清空，输入自动存草稿）。
- 新增工具准绳：纯本地可实现、能映射到 NGF 某一层能力、过质量门禁（单测 + 真机回归）才可上架。

### 3.1 本机纯逻辑验证工具链（`tools/verify/`）

本机通常没有 DevEco/hvigor，构建走 CI。但 `core/` 与 `tools/<id>/` 里的**纯逻辑**就是普通
TypeScript，可以用 Node 22 直接执行。`tools/verify/` 就是为此存在的：

```bash
# 跑 entry/src/test 下全部单测（真实单测，不是另写一套）
node --import ./tools/verify/register.mjs tools/verify/run.mjs

# 检查纯逻辑模块是否「干净可加载」（不 import ArkUI/设备能力）
node --import ./tools/verify/register.mjs tools/verify/run.mjs --logic

# 新增/删除测试文件后，重新生成 hypium 总入口
node tools/verify/gen-test-entry.mjs

# 页面/组件文件的结构性检查（组件名拼错、@Builder 漏括号、括号不配对、
# build() 里提前 return、调用了不存在的方法）
node tools/verify/check-pages.mjs

# 摘要算法与 Node 内置 crypto 对拍（含分组填充边界长度）
node --import ./tools/verify/register.mjs tools/verify/cross-verify-hash.mjs

# 接线一致性（元数据清单 ↔ 页面注册表 ↔ 工具目录 ↔ 单测 ↔ hypium 总入口 ↔ 路由表）
node --import ./tools/verify/register.mjs tools/verify/check-wiring.mjs

# 注释提前闭合扫描（见下方「第三个坑」）
node tools/verify/scan-comments.mjs

# 资源引用与多语言一致性（代码引用的键是否存在、三份资源表是否对齐、暗色色是否补齐）
node tools/verify/check-resources.mjs

# 主题对比度门禁（用本 App 自己的 WCAG 实现在两种主题上审计全部配色组合）
node --import ./tools/verify/register.mjs tools/verify/check-theme-contrast.mjs

# 双语覆盖面（每件工具还剩多少用户可见中文串；已完成的工具一旦回退即判失败）
node tools/verify/check-i18n.mjs

# 【可选，不进十道门禁】门禁自身的变异验证：故意破坏代码 → 确认门禁真的会失败。
# 它会临时改写工作区文件（每条跑完立即还原，结束时校验逐字节一致）；改过门禁脚本后手动跑。
node tools/verify/mutation-check.mjs
node tools/verify/mutation-check.mjs --restore   # 进程被强杀后从备份还原
```

### 3.2 ⚠️ 上面九道门禁**全都不查类型**——必须再跑真编译

九道门禁都跑在 Node 上，而 `tools/verify/register.mjs` 做的是**类型剥离**：
它把类型标注删掉再执行，**从不做类型检查**，也完全不认识 ArkUI 的 DSL。

所以下面这些错误可以在**九道门禁全绿**的同时存在：

- `$r()` 返回的是 `Resource`，却被传给了 `string` 形参
  - 实测**又踩过一次**：给 Toggle 加 `.accessibilityText($r('app.string.x'))` →
    真编译 `No overload matches this call`。正确写法是
    `.accessibilityText(ToolUiKit.text($r('app.string.x')))`（`ToolUiKit.text` 接 `string | Resource` 并返回 `string`）。
    九道 Node 门禁全绿，只有第十道抓到了。
- 枚举成员名写错、忘了 import（类型位置会被剥掉，所以 import 漏了也不报）
- `@Builder` 体里写了 `const` / `return`（Builder 只允许 UI 组件语法）
- ArkTS 专有禁令：`arkts-no-structural-typing`、`arkts-no-untyped-obj-literals`、
  `arkts-no-any-unknown`、`arkts-standalone-this`
- `WrappedBuilder` 这类「是全局类型、却被当成 import」的用法
- `ForEach` 的 keyGenerator 必须返回 `string`（返回 `ResourceStr` 会报）
- **二阶段新增实测**（第 100-131 轮沉淀）：组件成员名避开 `valueOf`/`toString`/`hasOwnProperty`
  （与 Object 原生方法同名会报「不能赋给 Object」的无关错误）；Select 选项必须显式类
  （`{value: x}` 字面量被禁）；`Map.get()` 返回 undefined 联合需显式判空；
  测试源码里的正则转义必须双反斜杠（`'\\w'` 单反斜杠会被剥类型器变成字面 w）；
  NGFToolCategory 只有 TEXT/COMPUTE/NETWORK/FILE 四类（写 DATA 必错）；
  build() 里只写 UI 语法（const/逻辑先行抽成方法）；资源键跨轮可能重复（表内唯一性靠编译器兜底）；
  方法内写 UI 语法必须标 @Builder（裸 private 方法报「; expected」）；
  禁嵌套函数（arkts-no-nested-funcs，辅助函数放模块顶层）；
  纯逻辑函数名避免大写开头（check-pages 会当组件名）；
  单行构造超长会被截断——长构造一律展开多行；
  排序输出要有确定性次级键（次数相同按字符码），否则测试断言不稳。

**实测踩过**：一轮开发里九道门禁全绿，真编译 **75 ERROR + 107 WARN**，
其中一个工具的页面被改到几乎编译不过。

所以本仓有**第十道门禁**：

```bash
pwsh -NoProfile -File tools/verify/build.ps1     # 真编译，退出码 0 = 无 ERROR
```

会自动探测 DevEco（`DEVECO_HOME` → 注册表 → 常见路径）。**找不到就报错退出，不会静默跳过**——
静默跳过正是这道门禁要防的事。

> **交活前必须十道全过。** 只报「九道门禁全绿」是不够的，那句话不蕴含「能编译」。

**⚠️ 增量空转会藏告警。** hvigor 在源码没变时把 `CompileArkTS` 标成 UP-TO-DATE，
那一趟**根本不跑 ArkTS 分析**，日志里一条告警都没有。
实测同一份代码：增量构建报「entry/ 2 条」，`clean` 后全量重编报「entry/ 5 条」——
漏掉的 3 条是一个真缺陷（框架组件把配置项声明成 `private`，运行时不渲染），藏了 11 轮。
`build.ps1` 现在会识别这种空转并明确提示「本次没有做 ArkTS 分析」，
**不再把空转报成「告警 0 条」**。改动过源码时 hvigor 会自动重编，无需手动 clean。

`check-resources.mjs` 还查**跨模块资源键冲突**：app（entry）与 HAR（ngf_framework）
定义了同名资源键时，打包会「先声明者胜出」**静默覆盖**，而 hvigor 只在构建日志里留一行
conflict 告警——本机九道门禁原本完全看不见。实测撞过一次（`about_copyright` 两边都有），
当时十道门禁全绿。现在它会把重名列出来；若确实是有意覆盖框架文案，
登记进脚本里的 `ALLOWED_OVERRIDES` 并写明理由。

`check-resources.mjs` 与 `check-theme-contrast.mjs` 补的是两类**构建期才发现**的坑：
前者是「`$r('app.string.X')` 的键不存在 → 构建失败」（本机没有构建，只有 CI 会报），
后者是「改了主题色导致某处文字读不清」（不报错、不失败，只有用户会发现）。
后者刻意**调用本 App 自己的 `ColorConvert.ets`** 而不是在脚本里另写一份 WCAG 公式——
两份公式迟早漂移，漂移之后门禁会开始骗人。

**元数据完整性检查在单测里，不在检查器脚本里。** `ToolsCatalogTest.test.ets` 覆盖了：
每件工具的 name/description/limitation **中英两侧都非空**、英文字段不含中日韩字符、
中文字段不含成段英文、英文 limitation 不含 markdown 星号、order 唯一、
每件工具至少声明一层 NGF 能力、**联网工具只有一件**（PR-002/PR-003 红线）。
排查「某个元数据字段为什么没被拦住」时先去那里看，别只 grep `tools/verify/*.mjs`——
实测这样误判过一次，以为 `limitation` 完全没有门禁。

> **测试套件做过变异验证**：把某工具的英文 `limitation` 真正清空 → 1 个用例失败；
> 把一件非联网工具改成 `usesNetwork: true` → 2 个用例失败。改动这些断言后建议重做一次。
> 注意变异必须**真的改变值**：写成 `'' + '原文'` 是无效变异（拼接空串值不变），
> 会让人误以为「测试没抓到」。

`check-wiring.mjs` 抓的是「加一件工具要同时改四处、漏改哪处都不报错」这类静默不一致：
漏登记元数据 → 首页没有这件工具；漏登记页面 → 点进去显示「建设中」；漏登记单测 → 真机上从不执行。
它同时核对**路由表**：新建 `@Entry` 页面却忘了加进 `main_pages.json`，真机上打开会失败，
而且编译期不报。**新增/删除工具或页面后必须跑它。**

`check-pages.mjs` 补的是「纯逻辑测不了、CI 又太慢」的那一层：它不编译、不执行，
只做静态结构核对，能在提交前抓出 `*Page.ets` 最常见的那几类错。
它**不能**替代编译（类型错误、属性类型不匹配查不出来）。

约束与边界（用它之前先读这一段）：

- 它**只**能跑不含装饰器（`@Component`/`@Entry`）且不 import ArkUI 的文件。
  带装饰器的页面会加载失败，这是预期行为，不是 bug。
- 它**不能**替代 CI 构建与真机回归：装饰器、资源引用、权限、生命周期都不在这里验证。
- `entry/src/test/List.test.ets` 由 `gen-test-entry.mjs` **生成**，不要手工编辑；
  hypium 没有自动发现机制，漏登记 = 测试在真机上从不执行。
- 纯逻辑文件中**不要**把「类型别名」和「运行时值」写进同一条 import：
  类型会被剥掉，可能连带丢掉同一条里的枚举值。类型别名请单独一条 import。
- **注释里不要写出「星号 + 斜杠」组合**：把「星号星号」加「斜杠」加数字写在一起
  （本意是加粗的 `/24` 这类前缀写法）会被当成**块注释结束符**，导致注释提前闭合、
  后面的代码掉到注释外——报错是难懂的 `Expected ';', '}' or <eof>`，而且**没有行号**。
  实测踩过两次（本工具的纯逻辑与单测各一次）。要写加粗的前缀，写成「前缀 24」。
  `scan-comments.mjs` 专门扫这个；它同时也被 `run.mjs --logic` 间接覆盖（模块加载不了）。
- **`$r()` 的入参必须是字符串字面量**：它由 ets-loader 在构建期静态改写成资源 ID，
  写成拼接（`$r('sys.symbol.' + name)`）**无效**，且不会在任何本机检查里报错，
  只在编译/真机上表现为「图标不显示」。动态取资源请建**字面量表**
  （范例见 `ui/ToolSymbols.ets`；`check-pages.mjs` 已加此项守卫）。
- `core/ToolNavigator.ets` 与各 `*Page.ets` 是预期的 ArkUI 依赖文件，
  已登记在 `tools/verify/run.mjs` 的 `ARKUI_DEPENDENT_FILES` 里。
- **改主题色必须同时跑 `check-theme-contrast.mjs`**，且 `base` 与 `dark` 两份
  `color.json` 的键必须完全一致（`check-resources.mjs` 会报缺键）。
  浅色主题的门槛比深色紧得多：深色下各组合普遍在 6:1 以上，
  浅色下有若干组只刚过 4.5:1，**动一下就会掉下去**。
- **用户可见文案分两类，机制不同，别混用**：
  - **固定标签**（按钮、小标题、空态、页脚）→ `$r('app.string.…')`，
    同时写进 `base` / `zh_CN` / `en_US` 三份 `string.json`。
    `check-resources.mjs` 会校验键存在、三表对齐，并且**漏翻译（中英相同）直接判失败**。
  - **内容数据**（工具元数据、关于页的能力/隐私/链接）→ `NGFLocalizedText`。
    因为这类数据在**纯数据层**，而纯数据层不能 `import` ArkUI 的 `$r()`
    （一旦 import，本机单测就构造不出来了）。
  - **工具内部文案**正在按件改造（样板见 `radix-convert`，流程写在
    `docs/开发交接.md` §二.3）。改造一件工具要动四处，缺一不可：
    纯逻辑加失败码 → 新增 `*Messages.ets` 做码到文案的映射 → 三份 `string.json` 加键
    → 单测改断言错误码。**别只挑几处改**，半翻译的界面比全中文更糟。
  - 改完一件就把它的 id 加进 `check-i18n.mjs` 的 `COMPLETED_TOOLS`，
    那道门禁会挡住回退；同时它会打印剩余进度，别再用「大概还有多少」估。

### 3.3 门禁变异验证记录（确认它们真的会失败）

**只会通过的门禁等于没有门禁。** 下面这些做过变异验证——故意破坏代码，
确认门禁**确实报错**、并且报的是对的地方。改动门禁后建议重做相关的几条。

| 门禁 | 变异 | 结果 |
|---|---|---|
| `check-theme-contrast` | 把次文本调亮（`#636E7E` → `#AAB2BC`） | ✅ 报 3 处，附具体比值 1.93 / 2.14 / 2.02 |
| `check-theme-contrast` | 某 Token 明暗填成同色 | ✅ 报「明暗两色相同，多半是漏填了一列」 |
| `run.mjs --logic` | 纯逻辑里塞 `$r()` | ✅ 报「不是纯逻辑：`$r()`（ArkUI 资源引用）」 |
| `run.mjs --logic` | 纯逻辑里 import ArkUI 的**值**并使用 | ✅ 报 1 个失败；单测同时从 620 掉到 610 通过 / 1 失败 |
| `check-i18n` | 往「已双语完成」的工具塞中文字面量 | ✅ 报出工具名与那句中文 |
| `check-resources` | 从 zh_CN 表删一个键 | ✅ 报「zh_CN/element/string.json 缺少键」 |
| `check-resources` | 工具页里写死 `'#FF0000'` | ✅ 报「出现硬编码色值」|
| `check-resources` | 删掉 `AppScope/resources/en_US` | ✅ 报「应用名没有本地化，该语言下桌面图标会用 base 的取值」|
| `check-pages` | 写一个不存在的组件名 | ✅ 报「用到未登记的组件名」 |
| `check-pages` | 语句位置漏 `@Builder` 括号 | ✅ 报「被引用时没有调用」 |
| `check-pages` | 删掉一个 `}` | ✅ 报「括号不配对：还有 1 个未闭合」 |
| `check-pages` | `build()` 顶层写 `return` | ✅ 报「ArkTS 不允许在 build() 中提前返回」 |
| `check-pages` | `$r('a' + 'b')` 拼接 | ✅ 报「入参不是字符串字面量」 |
| `check-pages` | 调用不存在的 `this.buildGhostHeader()` | ✅ 报「调用了本文件未声明的方法」 |
| `check-pages` | 去掉 Toggle 的 `.accessibilityText` | ✅ 报「第 N 行的 Toggle 没有 .accessibilityText」|
| `cross-verify-hash` | 改一个 SHA-256 轮常量 | ✅ 报「共比对 56 组，不一致 14 组」，退出码 1 |
| `check-wiring` §5.9 | 移走某个纯逻辑模块的测试 | ✅ 报「没有任何单测覆盖」 |
| `check-wiring` §5.10 | 删掉某工具模块的 `README.md` | ✅ 报「工具模块 X/ 没有 README.md」|
| `check-wiring` §5.11 | 把类型 `NGFToolId` 与值 `NGFLocalizedText` 写进同一条 import | ✅ 报「违反 PR-010」|
| `check-wiring` §5.8 | 路由表多一个不存在的页面 | ✅ 报「声明了不存在的页面」 |
| `check-wiring` §5.8 | 给非 Index 页加 `@Entry` | ✅ 报「没登记进 main_pages.json，真机上打开会失败」 |
| `check-wiring` §5.5 | 引用不存在的构建器 `buildGhostPage` | ⚠️ **修复前报 0 问题** → 见下方说明 |
| `check-wiring` §5.5 | 改名页面导出的构建器 | ✅ 报「没有导出 X（注册表引用名与页面导出名不一致）」 |
| `check-wiring` §5.5 | 删掉导出函数的 `@Builder` | ⚠️ **修复前报 0 问题** → 见下方说明 |
| `scan-comments` | 注释里写「星号 + 斜杠」 | ✅ 报出文件与行号 |
| `ToolsCatalogTest` | 真正清空某工具的英文 `limitation` | ✅ 1 个用例失败 |
| `ToolsCatalogTest` | 把非联网工具改成 `usesNetwork: true` | ✅ 2 个用例失败 |
| `check-i18n` | 把交接文档的双语进度改回「未做」 | ✅ 报「文档与门禁口径不一致，接手的人会信文档」|

**交接文档的口径也要跟门禁一致。** 实测 `docs/开发交接.md` 里**相邻两行**同时写着
「第 3 步（未做）」与「第 3 步（进行中）」，而门禁报的是 16/16、剩余 0——
文档与门禁各说各话，而接手的人只会信文档。`check-i18n` 现在会在「判定全部完成」
却仍看到那两句时判失败。**写文档里的进度时，以门禁输出为准，不要手写。**

**⚠️ `scan-comments.mjs` 曾是一道「不可能失败」的门禁。**

它报出「发现疑似提前闭合注释 N 处」之后**没有调用 `process.exit()`**——
而十道门禁的脚本是按**退出码**判定成败的。于是它在门禁里**从来没有失败过**，
一直以「通过」的姿态出现。

发现途径值得记下来：把变异验证**固化成脚本**（`tools/verify/mutation-check.mjs`）后，
这条变异的结果显示「**退出码 0（含预期片段）**」——输出里明明有 `[问题]`，退出码却是 0。
人工验证时我此前只看了输出文字，所以第 4 轮给它做「自测」时**误判为工作正常**。

> **教训**：门禁的判定基准是**退出码**。用输出文字判断「它工作了」是不够的——
> 一条永远 exit 0 的检查，输出再漂亮也是装饰。

> **同款缺陷第二例（2026-10-17 修复）**：`check-resources.mjs` 的**所有失败路径都没有
> `process.exit(1)`**——它报问题、输出正确，但退出码恒为 0，在十道门禁里从未失败过。
> 发现途径同样是变异验证脚本（3 条 check-resources 变异显示「退出码 0（含预期片段）」）。
> 修复后它立即抓到两个此前被放过的真问题：`pages/Index.ets` 的硬编码渐变色值
> （登记进 `HEX_ALLOWED`，属系统 API 入参数据）与 4 个专有名词键的「疑似漏翻译」误报
> （登记进 `SAME_IN_BOTH_LANGUAGES`）。修复后变异验证 17/0 全过。
> **规则**：给门禁脚本新增检查分支时，每条失败路径都必须以非零退出码结尾——
> 写完门禁脚本就跑一次 `node tools/verify/mutation-check.mjs`。

**§5.5 里曾有两处「假检查」，2026-10-16 修好并验证：**

1. 收集 `pages.set` 构建器名的正则是按旧的裸标识符写法 `pages.set('id', buildXPage)` 写的，
   而代码早已改成 `pages.set('id', wrapBuilder(buildXPage))`——**正则再也匹配不上任何一行**，
   `usedBuilders` 恒为空集，整个 §5.5 变成死代码却一直显示「0 问题」。
   修法是加一个可选的 `wrapBuilder(\s*` 前缀。
2. `@Builder` 检查写的是 `pageSource.indexOf('@Builder') < 0`——查的是**整个文件**里有没有，
   而工具页里必然还有别的 `@Builder` 方法，所以那个条件**永远为假**。
   改成只匹配「`@Builder` + `export function <构建器名>`」这一对。

**教训**：门禁的「0 问题」有两种含义——「检查通过」和「检查没跑」。
定期用变异区分这两者，不然假绿会一直绿下去。

**退出码也验过**：上面每一条变异都确认了 `exit 1`（`.ps1` 那条由 `build.ps1` 的退出码承担），
还原后 `exit 0`。门禁是按退出码判定的，只看输出文字不够。

**这些验证已经脚本化**：`node tools/verify/mutation-check.mjs`——
17 条变异，逐条注入 → 跑门禁 → 断言「退出码非零 **且** 输出含预期诊断」→ 还原，
最后校验所有触及文件**逐字节一致**。它**不进十道门禁**（会改工作区、且跑得慢），
在**改动任何门禁脚本之后**手动跑一次即可。

加新变异时注意两个已踩过的坑：① 变异必须**真的改变值**（`'x'` 替换掉一整句
不是「清空」，测试不会失败）；② `expect` 要写**那条检查真正的诊断片段**
（「未登记的组件名」与「未声明的方法」是两条不同检查）。

**到 2026-10-16 为止，十道门禁的每一项子检查都有对应的变异验证。**
新增检查项时请一并补一行——没有这一行，就无法区分「检查通过」和「检查没跑」。

**已知的一条「抓不到」**：纯逻辑里 `import { X } from '@kit.ArkUI'` 但**只当类型用**时，
`--logic` 不报。这不是缺口——类型会被 `register.mjs` 剥离，不影响该模块在 Node 里可测。
但当**值**用（如上表）就会被抓。

**做变异时的坑**（实测踩过）：变异必须**真的改变值**。写成 `'' + '原文'` 是无效变异
（拼接空串值不变），会让人误以为「测试没抓到」。第一次变异 `limitation` 时就栽在这里。

### 3.4 真机验证回路（**每轮必做**）

本机**连着真机**，所以「交活前跑一次真编译」不够——必须装上去看。

```bash
# 设备（nova 12 Ultra，就是开发者截图那台；另一台 MatePad Mini 是平板）
HDC='G:/DevEco Studio 26/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe'
T=192.168.5.124:44879

hdc -t $T install -r entry/build/default/outputs/default/entry-default-signed.hap
hdc -t $T shell aa force-stop com.dlzz.ngftoolbox
hdc -t $T shell aa start -a EntryAbility -b com.dlzz.ngftoolbox
sleep 6
hdc -t $T shell snapshot_display -f /data/local/tmp/s.jpg
hdc -t $T file recv /data/local/tmp/s.jpg ./_s.jpg     # 然后用 read_image 看
hdc -t $T shell uinput -T -c 196 1060                  # 点击（坐标是**物理像素**）
hdc -t $T shell "hilog -x | grep A01F00 | tail -40"    # 应用侧日志域
```

**为什么必须做**：十道门禁全绿的情况下，真机上连续出现过——
首页整块空白、工具页没有返回按钮、历史按钮被裸 `{ }` 块吞掉、状态栏不沉浸、
搜索框被顶栏背景压住、报错文案里漏出字面的 `%s`。**这些没有任何一道门禁能发现。**

> **回报问题时先截图再改。凭想象改的每一轮都是浪费。**

> ## 📖 详细手册：[**`docs/真机验证手册.md`**](docs/真机验证手册.md)
>
> **动手验之前先读它。** 那里有全部已验结论（深色模式、字体缩放、输入历史、收藏、搜索、
> 错误态…）与**每一条踩过的坑**——坐标怎么定位、退格键码是多少、键盘挡住了怎么办、
> 多行输入是哪个控件、花括号怎么打…
>
> **每一条都对应一次真实的误判。** 其中大部分不是产品的问题，而是**验证手段本身的问题**。


### 3.5 设备端跑全部单测（hypium / ohosTest，2026-10-16 打通）

**638 个单测可以在真机上跑。** 这是唯一能发现「本机桩掉了、真机没有」这类问题的通道。

```bash
DEVECO='G:/DevEco Studio 26/DevEco Studio'
$DEVECO/tools/node/node.exe $DEVECO/tools/hvigor/bin/hvigorw.js \
  --mode module -p module=entry@ohosTest -p product=default -p buildMode=debug \
  assembleHap --no-daemon                      # 需要 DEVECO_SDK_HOME=$DEVECO/sdk

hdc install -r entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap
hdc shell aa test -b com.dlzz.ngftoolbox -m entry_test \
  -s unittest OpenHarmonyTestRunner -s timeout 180000
# 失败用例要从 hilog 里捞：hdc shell "hilog -x | grep '\[fail\]'"
```

`entry/src/ohosTest/ets/test/List.test.ets` **只是一行转发**到 `entry/src/test/List.test.ets`，
所以「设备上跑的」和「本机跑的」永远是同一批用例，不会漂移。

**打通时发现的两件事（都很值得记）：**

1. **23 个类型错误一直隐形。** 测试文件不在 app 构建范围内，
   而本机 harness 只剥类型——所以 8 个测试文件里躺着 23 个真类型错误
   （缺 import 11 个、可能为 null 7 个、类型不匹配 5 个），从没被任何检查发现。
   要编进 ohosTest 才暴露出来，已全部修掉。
2. **9 个用例曾在真机上全挂、本机全过（已修）。** 全部集中在 `ToolStateStore` 的持久化：
   它们要求「存储**可控且已就绪**」，而真机用的是框架真实存储，测试里切不动。
   本机 harness 把存储桩掉了（`globalThis.__NGF_STUB_STORE__`），所以看不出来。

   **真正的教训在注释里**：那个测试文件的文件头写着「真机上……会优雅跳过」——
   **而代码里从来没有那个分支**。注释描述的是一个**没实现的意图**，
   于是真机上它们以「真实存储」运行，9 条全挂。
   已补上 `if (storeControl() === null) { return; }` 守卫。

   修完：**设备端 637 跑 / 0 失败 / 637 通过。**

   > 顺带解开一个疑点：`freshStore(true)`（要求存储**未就绪**）那 3 条在真机上反而通过——
   > 因为框架没引导，`load()` 真的返回 false，**碰巧**符合期望。
   > **它们是「对的答案、错的原因」。** 这类通过比失败更危险：失败会让人去查，通过不会。

   **⚠️ 增量构建会让这个改动看起来没生效。** 修完第一次重跑，设备上仍是 9 条失败，
   而日志写着 `BUILD SUCCESSFUL in 2s554ms`——那是增量命中，测试根本没重编。
   必须删掉 `entry/build/default/intermediates/loader_out/ohosTest` 与
   `entry/build/default/outputs/ohosTest` 再重建（16 秒）才真正生效。

**已知的两类「编译通过但运行时不渲染」**（本仓实机踩过）：

1. **裸 `{ ... }` 块包住的组件不渲染**。ToolScaffold 的历史按钮曾写成
   `{ SymbolGlyph(...) }`，编译无错，实机上整个按钮消失（旁边没包的同款按钮正常）。
   写成与相邻兄弟一致的平铺形式即可。
2. **跨组件传带参 `@BuilderParam` 不渲染**。见 `ngf_framework/VENDORED.md`。
   框架 `uiShell` 的 `NGFHdsImmersiveTabs` 即因此弃用，
   首页改为直接 `HdsTabs` + 内联 `TabContent`（与来源仓 `MainMenuPage` 一致）。

## 4. 框架副本纪律

- `ngf_framework/` 是 vendored 副本：框架改动原则上回来源仓（airwavefootprints）修改验证后再同步；本仓内的先行试验必须在 `ngf_framework/VENDORED.md` 追记。
- 不要在本仓给框架加业务逻辑；工具箱业务只写在 `entry/`。

## 5. 已定事项（不要再议）

- 产品名：NGF 开发者工具箱；包名：`com.dlzz.ngftoolbox`；仓库：`DaLongZhuaZi/ngf-toolbox`；许可证：MIT；完全免费；开源。
- 版本：`AppScope/app.json5` 的 versionName/versionCode 是唯一版本源，发布时两处（app.json5 与 Release tag）保持一致。
- 签名：仓库不提交签名材料；本地用 DevEco 自动签名，CI 剥离签名出未签名包，发布签名走 sign-and-release（v* tag + Secrets）。
- ⚠️ **提交前必查 `build-profile.json5`**：DevEco 的本地自动签名会把
  `signingConfigs`（含 `keyPassword` / `storePassword` / `certpath` / `storeFile`）
  **写进这个文件**，而它**是被 git 跟踪的**——一次 `git add .` 就会把签名材料提交上去。
  `HEAD` 版本目前是干净的（已核实），别让它变脏。
  检查方法：`git diff build-profile.json5` 里不该出现 `storePassword` / `keyPassword`。
  CI 侧有 `.github/scripts/strip_signing.py` 兜底，但**那管不到本地提交**。

**本地签名与提交的共存（2026-10-18 落地）**：`build-profile.json5` 已用
`git update-index --skip-worktree` 标记。这样**本地可以保留 DevEco 自动生成的签名配置**
（真机装机需要），而 `git status` 保持干净、不会误提交。

- 查标记：`git ls-files -v build-profile.json5`，首列 `S` 表示已标记；
- 解除（要改这个文件并提交时）：`git update-index --no-skip-worktree build-profile.json5`；
- ⚠️ 如果**远端**改了这个文件，pull 前必须先解除标记，否则会冲突。

提交前仍要按上面那条复核一遍——标记只防误提交，不防你自己 `git add -f`。
