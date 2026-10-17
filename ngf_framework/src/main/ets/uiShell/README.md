# ngf-ui-shell

统一的壳层：导航、页面策略，以及**一批可直接复用的 HDS / 沉浸式 UI 组件**。

## 目录

| 目录 | 内容 |
|---|---|
| `contracts/` | `INavigationShell`、`IPagePolicyHost`、`IRouteInterceptor`、`IDeepLinkHandler`、`IPageStateStore`、`IPageTransitionManager`、`IOverlayManager` |
| `facades/` | `NavigationShellFacade`、`PagePolicyHostFacade`、`RouteInterceptorFacade`、`DeepLinkFacade`、`PageStateStoreFacade`、`PageTransitionManagerFacade`、`OverlayManagerFacade` |
| `components/` | **可直接用的 UI 组件**，见下表 |

## components/ 里有什么（这部分以前没写，导致被整体忽略过）

| 组件 | 提供什么 |
|---|---|
| `NGFHdsTabsFactory` | `NGFHdsImmersiveTabs` —— 基于 `@kit.UIDesignKit` 的 `HdsTabs`，IMMERSIVE 材质 + 浮动底栏 + 自适应握持。<br>⚠️ **已知缺陷（2026-10-16 真机实测）**：页签条能正常显示，但 **`TabContent` 里的内容一个像素都不渲染**——父组件传进来的 `contentBuilder` 根本没被调用。这是框架里**唯一**一处带参 `@BuilderParam`（其余组件全是无参形式），该路径此前从未被验证过。使用前请先在真机确认。<br>另注：父组件要传入的配置项**不能**声明成 `private`，否则 ArkTS 只给一行 WARN，运行时页签一个都不渲染。 |
| `NGFImmersiveTopChrome` | `NGFImmersiveTopChromeUnderlay` 沉浸式顶栏底板（渐变 + 光晕 + 材质模糊），以及 `ngfImmersiveContentTop()`。**底板合成在内容之上**，内容必须用后者避让，写死数字会被压暗甚至挡住。 |
| `NGFPageTemplates` | `NGFListPageTemplate` / `NGFDetailPageTemplate` / `NGFFormPageTemplate` 三种页面骨架 + `NGFKeyValueEntry`。适合列表 / 详情 / 表单形状的页面；形状不匹配时不要硬套。 |
| `NGFHdsEffectPresets` | HDS 材质与阴影预设（`NGFHdsSystemMaterialParams`、`NGFHdsBackgroundEffectOptions`、`NGFHdsShadowOptions` 等）。 |
| `NGFMaterialSurfaceTokens` | 材质表面相关的 Token 与选项工厂。 |
| `HdsNavigationSupport` | `NGFHdsTitleBarOptionsFactory` —— HDS 标题栏选项。 |
| `AboutSheetContent` | 完整的「关于」半模态内容。**它依赖宿主 app 提供 `app.color.*` 与 `app.string.about_*` 资源**（本框架的 `resources/` 里已有那批键）。 |
| `NGFControlStyleTokens` | 控件样式 Token。 |

**上面这些组件都依赖 `ngf_framework/src/main/resources/` 里的资源表**
（base 字符串 1303 键、颜色 108 键）。宿主 app 若定义同名资源键，
打包时会「先声明者胜出」**静默覆盖**——给自定义键加前缀可避开。

## 用法与踩坑

组件的具体用法、所需的宿主资源、以及实测踩过的坑（避让数值、`private` 声明、
增量构建藏告警），见使用本框架的样板仓里的 `docs/NGF框架能力清单.md`。

## 当前状态

契约与门面层已完整；`components/` 下的组件均已实现并可用。
新增能力请继续放在本层，不要在业务仓里另起一套壳层。
