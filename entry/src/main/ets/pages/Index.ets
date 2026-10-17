/**
 * NGF 开发者工具箱首页。
 *
 * ## 这个页面刻意「不认识任何一件具体工具」
 *
 * 首页只做四件事：搜索、收藏、最近使用、按分类铺网格。
 * 四件事的数据全部来自 {@link toolRegistry}（元数据）与
 * {@link toolStateStore}（用户状态），代码里**没有任何一处**出现具体工具的
 * id、名称或跳转逻辑。因此新增一件工具不需要改动本文件一个字符——
 * 这是产品定义稿 §一「工具可扩展架构」在 UI 层的落点，
 * 也是本 App 作为「样板应用」最值得读者看的一段代码。
 *
 * ## 用户状态的加载时序（一个真实的坑）
 *
 * 收藏/最近使用存在框架的 Preferences 里，而它的初始化是**异步**的
 * （见 application/ToolboxApplication.ets 的说明）。首页因此**不能**在
 * aboutToAppear 里读一次就完事——那时大概率还没就绪，用户真实的收藏会被
 * 显示成「空」。这里用一个**有上限**的短轮询来等它，拿到就立刻停。
 *
 * 为什么有上限：若 Preferences 因异常始终不就绪，无限等会让首页永远停在
 * 「加载中」。到时更该做的是把工具网格先显示出来（工具本身完全可用），
 * 只是收藏区暂时为空——工具能用，比收藏显示得准更重要。
 *
 * @module pages/Index
 */

import { NGFNavigationParamEnvelope } from 'ngf_framework';
import { ABOUT_ROUTE_NAME, readToolIdFromPayload, TOOL_HOST_ROUTE_NAME } from '../core/ToolRoutes';
import { ToolContext } from '../core/ToolPageContract';
import { AboutView } from './AboutPage';
import { ToolHostView } from './ToolHostPage';
import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../ui/FontScaleSource';
import {
  NGFColorToken,
  NGFHdsEffectPresetFactory,
  NGFHdsTitleBarOptionsFactory,
  logger
} from 'ngf_framework';
import {
  HdsNavDestination,
  HdsNavigation,
  hdsMaterial,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  HdsTabsFloatingStyle,
  SystemMaterialParams
} from '@kit.UIDesignKit';
import { colorOf, TOOLBOX_DARK_KEY } from '../ui/ThemeSource';
import { FULLSCREEN_CHROME, FULLSCREEN_GLOW_PRIMARY, FULLSCREEN_GLOW_SECONDARY, titleBarBackground, titleBarScrolledBackground, titleBarTitleColor, titleBarSubtitleColor } from '../ui/ImmersiveChrome';
import { applyWindowChrome, CONTENT_BOTTOM_INSET, HOME_TITLE_BAR_HEIGHT, loadDynamicInsets } from '../ui/WindowChrome';
import { ToolUiKit } from '../ui/ToolUiKit';
import { toolboxApplication } from '../application/ToolboxApplication';
import { cardWidthFor, columnsForWidth, GridLayoutSpec } from '../core/ToolGridLayout';
import { NGFLocalizedText, NGFToolMeta, NGFToolSearchHit } from '../core/ToolModel';
import { groupToolsByCategory, NGFToolCategoryGroup, toolRegistry } from '../core/ToolRegistry';
import { openAboutPage, openTool } from '../core/ToolNavigator';
import { ToolUseState } from '../core/ToolStateModel';
import { toolStateStore } from '../core/ToolStateStore';
import { currentLocale, FALLBACK_LOCALE } from '../ui/LocaleSource';
import { NETWORK_BADGE_SYMBOL, toolSymbolOf } from '../ui/ToolSymbols';

const TAG: string = 'Index';

/** 首页左右留白（vp） */
/** 顶栏背景层比文字区多出的高度（vp），见 build() 里的说明 */
const TITLE_BAR_MASK_EXTRA: number = 28;
const PAGE_PADDING: number = 16;
/** 网格卡片之间的间距（vp）；必须与卡片自身的 margin 一致，否则填不满一行 */
const CARD_GAP: number = 12;
/** 用户状态轮询间隔与上限 */
const STATE_POLL_INTERVAL_MS: number = 150;
const STATE_POLL_MAX_ATTEMPTS: number = 20;

/** 页签按压反馈时长（ms）——与来源仓 MainMenuPage 一致 */
const MOTION_TAB_PRESS: number = 180;
/** 页签切换动画时长（ms）——与框架 Navigation 转场同量级 */
const MOTION_TAB_SWITCH: number = 250;

/**
 * 悬浮底栏样式。
 *
 * ## 字段来自 SDK 的 `HdsTabsFloatingStyle`（@hms.hds.hdsBaseComponent.d.ets）
 *
 * 该接口一共 10 个字段，**只写 4 个是不够的**——尤其这三个直接决定「浮不浮」：
 *
 * | 字段 | 作用 | 不写会怎样 |
 * |---|---|---|
 * | `barSideMargin` | 栏与屏幕**左右**的间距 | 栏横向撑满，看不出是「浮起的一块」 |
 * | `barBottomMargin` | 栏与 tabs 底部的间距 | 栏**贴着屏幕底边**，悬浮感消失 |
 * | `systemMaterialEffect` | 系统材质（毛玻璃） | 栏是一块纯色，没有材质层次 |
 *
 * 材质参数**不在本仓手写**，而是用框架的
 * `NGFHdsEffectPresetFactory.buildSystemMaterialParams()`——它与框架其它组件
 * （如 `HdsNavigationSupport`）共用同一套预设，避免「首页底栏的材质等级和
 * 顶栏不是一个来源」这种漂移。
 */
class ToolboxTabFloatingStyle implements HdsTabsFloatingStyle {
  adaptToHandedness?: boolean;
  systemMaterialEffect?: SystemMaterialParams;
  thermoCtrl?: boolean;
  barOpacity?: number;
  barBottomMargin?: Length;

  /**
   * @param level        材质等级（跟随框架视觉设置）
   * @param bottomMargin 底部间距＝**系统手势条实测高度**（vp），由调用方传入
   */
  constructor(level: hdsMaterial.MaterialLevel, bottomMargin: number) {
    this.adaptToHandedness = true;
    this.systemMaterialEffect =
      NGFHdsEffectPresetFactory.buildSystemMaterialParams(hdsMaterial.MaterialType.IMMERSIVE, level);
    this.thermoCtrl = true;
    this.barOpacity = 0.95;
    this.barBottomMargin = bottomMargin;
  }
}

@Entry
@Component
struct Index {
  /** 订阅主题深浅；本字段本身不用，作用是在主题切换时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  /** 订阅字体缩放；本字段不用，作用是切字号时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @State private keyword: string = '';
  @State private toolUseState: ToolUseState = ToolUseState.empty();
  @State private gridWidth: number = 0;
  @State private columns: number = 1;
  @State private cardWidth: number = 156;
  /** 当前语言。工具名与分类名按它取，见 ui/LocaleSource 的说明 */
  @State private locale: string = FALLBACK_LOCALE;
  /**
   * 当前页签索引。
   *
   * 0 是「收藏与最近」，其后依次是各工具分类（顺序与产品定义稿 §四 一致）。
   * 索引由父组件持有并驱动 HdsTabs（框架的组件不自己改 selectedIndex），
   * 所以这里存一份状态、用 onChangeCallback 回写。
   */
  @State private homeTabIndex: number = 0;
  /** 当前被按住的页签索引（-1 = 无）；只用于按压反馈 */
  @State private pressedTabIndex: number = -1;
  /**
   * 框架的「视觉强度」设置值（材质等级）。本字段只用于底栏材质，
   * 与框架组件读同一个存储键，保证全局一致。
   */
  @StorageProp('ngf_visual_effects_effective_material_level')
  private tabMaterialLevel: number = hdsMaterial.MaterialLevel.ADAPTIVE;

  /**
   * 顶部内容避让（vp）＝**实测状态栏高度** + 顶栏高度。
   *
   * 初值用经验值而不是 0：避免首帧内容被顶栏压住闪一下；
   * aboutToAppear 里会立刻用 loadDynamicInsets 换成实测值。
   */
  @State private topInsetVp: number = HOME_TITLE_BAR_HEIGHT + 28;

  /**
   * 底部避让（vp）＝**系统手势条实测高度**，专供悬浮底栏的 `barBottomMargin`。
   *
   * 为什么不能用写死的值：各机型手势条高度不同（本机实测 10vp，无手势条设备为 0）。
   * 写死 16 时，栏要么离底太远、要么压到手势条上。原版 MainMenuPage 同样取
   * `TYPE_NAVIGATION_INDICATOR` 的 bottomRect 高度，本仓复用已有的
   * {@link loadDynamicInsets}，不另写一份窗口查询。
   *
   * 初值 0：拿不到时**宁可贴底**也不要凭空留一段空白（原版的降级值也是 0）。
   */
  @State private bottomInsetVp: number = 0;

  /** HdsTabs 控制器：框架要求由调用方持有并传进 HdsTabs */
  private tabsController: HdsTabsController = new HdsTabsController();

  /**
   * 根导航栈。**整个 App 只有这一个**——工具页与关于页都是它上面的 destination，
   * 不再各自是独立页面（首版用 router.pushUrl 跳独立页面，已废弃）。
   *
   * ⚠️ 必须写进 AppStorage 的 **'GlobalNavStack'** 键：框架的
   * \`ngfNavigationShellFacade\` 就是从这个键取栈的
   * （见 uiShell/facades/NavigationShellFacade.resolveNavStack）。
   * 键名是硬约定，**拼错不会报错**，只表现为「点了工具没反应」。
   */
  private pathStack: NavPathStack = new NavPathStack();

  private pollAttempts: number = 0;
  private pollTimer: number = -1;

  aboutToAppear(): void {
    // 注册导航栈供框架门面使用。必须在首帧之前完成：
    // 首页一渲染出来用户就可能点工具，那时门面必须已经能取到栈。
    AppStorage.setOrCreate<NavPathStack>('GlobalNavStack', this.pathStack);
    // 首帧先用兜底宽度算一次列数，避免网格闪一下单列再跳成多列。
    this.measureGrid(0);
    this.loadUserState();
    this.locale = currentLocale();
    // 窗口级沉浸 + 系统栏图标色
    applyWindowChrome(this.isDark);
    // 顶部避让用**实测**状态栏高度，不是猜的值（各机型不一样）。
    // 初值只是防首帧闪一下，这里会立刻换掉。
    loadDynamicInsets(this.getUIContext(), 28, 0, (top: number, bottom: number): void => {
      this.topInsetVp = top + HOME_TITLE_BAR_HEIGHT;
      // 底部值此前被丢弃了——悬浮底栏的 barBottomMargin 正需要它。
      this.bottomInsetVp = bottom;
    });
  }

  /**
   * 页面重新可见时重读语言（App 回到前台等）。
   *
   * ⚠️ **它不再覆盖「从工具页返回」这个场景。** 导航迁到 NavPathStack 之后，
   * 工具页只是同一个页面上的 destination 出栈，页面本身没有隐藏过，
   * onPageShow **不会**触发。迁移前这里是唯一的语言刷新点，迁移后会漏掉返回场景——
   * 返回场景改由 onNavBarStateChange 兜住（见 build 里的说明）。两处都要保留。
   */
  onPageShow(): void {
    this.locale = currentLocale();
  }

  aboutToDisappear(): void {
    // 必须清：页面销毁后定时器还在跑会持续读存储，也会引用已销毁的组件状态。
    this.stopPolling();
  }

  /**
   * 按可用宽度重算列数与卡片宽度。
   *
   * ## 为什么不读取「屏幕宽度」，而是量「布局实际宽度」
   *
   * 屏幕宽度不等于内容区宽度：手机上要减去左右留白，折叠屏展开/悬浮窗/
   * 分屏时窗口宽度又和屏幕宽度不同。直接拿屏幕宽度算列数，在这些形态下
   * 会算出偏多的列，卡片被压扁、说明文字被截断。
   * 用 `onAreaChange` 拿到的是**真实分配到这个 Column 的宽度**，
   * 天然把这些差异都算进去了。
   *
   * ## 为什么换算用 UIContext 而不是全局 px2vp
   *
   * `onAreaChange` 回调给的是 px。全局 `px2vp()` 在非 UI 线程或
   * UIContext 未绑定时会抛异常；`this.getUIContext().px2vp()` 由组件自己保证
   * 上下文正确。失败时退化为「按像素当 vp」——宁可列数略多，
   * 也不要因为取不到宽度而整页空白。
   */
  private measureGrid(widthValue: number): void {
    let available: number = 0;
    if (widthValue > 0) {
      // ⚠️ **onAreaChange 给的是 vp，不是 px**（本 SDK 版本真机实测：
      // 屏宽 376vp 的手机上回调约 362.67）。旧代码按 px 处理并过了 px2vp，
      // 把 362.67 又除以 3.25 得到 111.6vp，再减两侧留白 → available=75.5，
      // 于是 columns=1、cardWidth=75，卡片窄到只能显示两个字（真机截图确认）。
      //
      // 现在按 vp 直接用。同时留一条兜底：数值明显超出 vp 合理范围时按 px 处理，
      // 以防将来某个 SDK 版本改回 px——两种单位下都不会算出荒唐的列数。
      const widthVp: number = widthValue > 1200 ? widthValue / this.pixelDensity() : widthValue;
      available = widthVp - PAGE_PADDING * 2;
    }
    if (available <= 0) {
      // 首帧拿不到宽度时的兜底：按常见手机宽度 360vp 估算，
      // 真实宽度到达后 onAreaChange 会再算一次。
      available = 360 - PAGE_PADDING * 2;
    }
    this.gridWidth = available;
    this.columns = columnsForWidth(available, GridLayoutSpec.standard());
    this.cardWidth = cardWidthFor(available, this.columns, GridLayoutSpec.standard());
    logger.info(TAG, '网格测量: 回调值=' + String(widthValue) + ', available=' + String(available)
      + ', columns=' + String(this.columns) + ', cardWidth=' + String(this.cardWidth));
  }

  /**
   * 屏幕像素密度（1vp 等于几个 px）。
   *
   * 取不到时返回 1——宁可把宽度当 vp 用（那是当前 SDK 的行为），
   * 也不要因为一次换算失败整页算错。
   */
  private pixelDensity(): number {
    try {
      const vpFor1000Px: number = this.getUIContext().px2vp(1000);
      return vpFor1000Px > 0 ? 1000 / vpFor1000Px : 1;
    } catch (error) {
      return 1;
    }
  }

  /**
   * 加载用户状态（收藏 / 最近使用）。
   *
   * 框架的 Preferences 初始化是**异步**的，`toolboxApplication.initialize()`
   * 返回时它多半还没就绪，所以先试一次；没就绪就短轮询等它——
   * 超时后先展示工具网格，不再阻塞首帧（宁可少显示收藏，也不要白屏）。
   */
  private loadUserState(): void {
    if (toolboxApplication.reloadUserState()) {
      this.toolUseState = toolStateStore.getState();
      return;
    }
    this.pollAttempts = 0;
    this.stopPolling();
    this.pollTimer = setInterval((): void => {
      this.pollAttempts += 1;
      if (toolboxApplication.reloadUserState()) {
        this.toolUseState = toolStateStore.getState();
        this.stopPolling();
        return;
      }
      if (this.pollAttempts >= STATE_POLL_MAX_ATTEMPTS) {
        logger.warn(TAG, '用户状态加载超时，先展示工具网格');
        this.stopPolling();
      }
    }, STATE_POLL_INTERVAL_MS);
  }

  private stopPolling(): void {
    if (this.pollTimer !== -1) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  private hitMetas(): Array<NGFToolMeta> {
    const metas: Array<NGFToolMeta> = [];
    const hits: Array<NGFToolSearchHit> = toolRegistry.search(this.keyword);
    for (let i: number = 0; i < hits.length; i++) {
      metas.push(hits[i].meta);
    }
    return metas;
  }

  /** 收藏区要展示的工具（保持收藏顺序；跳过注册表里已不存在的 id） */
  private favoriteMetas(): Array<NGFToolMeta> {
    return this.metasOf(this.toolUseState.favorites);
  }

  /** 最近使用区要展示的工具 */
  private recentMetas(): Array<NGFToolMeta> {
    return this.metasOf(this.toolUseState.recents);
  }

  private metasOf(ids: Array<string>): Array<NGFToolMeta> {
    const metas: Array<NGFToolMeta> = [];
    for (let i: number = 0; i < ids.length; i++) {
      const meta: NGFToolMeta | null = toolRegistry.getMeta(ids[i]);
      if (meta !== null) {
        metas.push(meta);
      }
    }
    return metas;
  }

  /** 页签标题：0 号是收藏与最近，其后是各分类 */
  private tabTitles(): Array<string> {
    const list: Array<string> = [];
    list.push(ToolUiKit.text($r('app.string.shell_tab_starred')));
    const groups: Array<NGFToolCategoryGroup> = groupToolsByCategory(toolRegistry, this.locale);
    for (let i: number = 0; i < groups.length; i++) {
      list.push(groups[i].label);
    }
    return list;
  }

  /**
   * 全屏沉浸底板（结构照搬 NGF 原版 `MainMenuPage.buildFullscreenBackgroundUnderlay`）。
   *
   * ⚠️ **是全屏，不是顶部一条。** 原版的沉浸感来自铺满整屏的渐变 + 光晕球。
   *
   * **第二阶段起按主题取色**：框架加了 buildAdaptive() 之后标题色可配，
   * 不再需要为「白字」把底板染成恒深。
   * 深色沿用 FULLSCREEN_CHROME 深蓝渐变（那套就是为深色沉浸调的）；
   * 浅色用系统列表页同款的浅灰白——标题、底板、内容**同色一体**，
   * 分界线消失（对照系统「电话」应用的大标题形态）。
   */
  @Builder
  private buildFullscreenChrome() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {}
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 150,
          colors: this.isDark ? [
            [FULLSCREEN_CHROME[0], 0],
            [FULLSCREEN_CHROME[1], 0.28],
            [FULLSCREEN_CHROME[2], 0.58],
            [FULLSCREEN_CHROME[3], 0.82],
            [FULLSCREEN_CHROME[4], 1]
          ] : [
            ['#F7F9FC', 0],
            ['#F2F5FA', 0.28],
            ['#EEF2F8', 0.58],
            ['#EDF1F7', 0.82],
            ['#E9EDF4', 1]
          ]
        })

      // 右上光晕
      Column() {}
        .width(176)
        .height(176)
        .borderRadius(176)
        .backgroundColor(FULLSCREEN_GLOW_PRIMARY)
        .opacity(this.isDark ? 0.22 : 0.10)
        .margin({ left: 192, top: 12 })

      // 左上光晕
      Column() {}
        .width(148)
        .height(148)
        .borderRadius(148)
        .backgroundColor(FULLSCREEN_GLOW_SECONDARY)
        .opacity(0.18)
        .margin({ left: 18, top: 28 })
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 分类页签（**框架的 HdsTabs**）。
   *
   * ## 为什么上一版是空白的
   *
   * 上一版用了框架的包装组件 `NGFHdsImmersiveTabs`，它把内容做成一个
   * **带参数的 `@BuilderParam`** 由父组件传进去——真机上**只画出页签条，
   * TabContent 里什么都不渲染**。而原版 `MainMenuPage` 用的是
   * **直接写 `HdsTabs` + `TabContent` 内联内容**，从不跨组件传 builder。
   *
   * 现在照原版来：内容在 `TabContent` 里直接调本组件的 `@Builder`。
   */
  @Builder
  private buildHdsTabs() {
    // ⚠️ 页签**逐个写死，不用 ForEach**。
    //
    // 这是照 NGF 来源仓的做法：翻遍 `MainMenuPage`(2207 行) 与
    // `HdsIntegratedShowcasePage`，**每一处 TabContent 都是显式写的**——
    // 连「三个页签用同一个 builder、只差标题、本该用 ForEach」的地方也是写死的。
    //
    // 本仓在这个组件上栽过一次（页签条画出来、内容全空）。当时混合了两个变量
    // （ForEach 生成 TabContent + 跨组件传带参 @BuilderParam），无法归因。
    // 既然参考实现里没有先例，就不赌——把 ForEach 这个变量彻底去掉。
    //
    // 数量固定为 5（收藏 + 4 个分类）的依据：
    //   NGFToolCategory 枚举恰好 4 个成员，groupToolsByCategory 只丢弃空分类。
    //   「每个分类都非空」由单测 ToolsCatalogTest 守住——把假设变成门禁，
    //   而不是靠记忆。
    HdsTabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
      TabContent() {
        this.buildTabBody(0)
      }
      .tabBar(this.buildTabItem(this.tabTitleAt(0), $r('sys.symbol.square_on_square_fill'), 0))

      TabContent() {
        this.buildTabBody(1)
      }
      .tabBar(this.buildTabItem(this.tabTitleAt(1), $r('sys.symbol.doc_text'), 1))

      TabContent() {
        this.buildTabBody(2)
      }
      .tabBar(this.buildTabItem(this.tabTitleAt(2), $r('sys.symbol.arrow_left_arrow_right'), 2))

      TabContent() {
        this.buildTabBody(3)
      }
      .tabBar(this.buildTabItem(this.tabTitleAt(3), $r('sys.symbol.network_acceleration'), 3))

      TabContent() {
        this.buildTabBody(4)
      }
      .tabBar(this.buildTabItem(this.tabTitleAt(4), $r('sys.symbol.externaldrive'), 4))
    }
    .width('100%')
    .layoutWeight(1)
    .barMode(BarMode.Fixed)
    // 浮动栏压在内容之上，所以内容底部要留白（见 buildTabBody）
    .barOverlap(true)
    // ⚠️ 下面这行才是「悬浮胶囊底栏」的开关。缺了它，栏会贴着屏幕底边成一条通栏，
    // 只有文字没有容器——真机上一眼就能看出不像系统应用的页签。
    .barFloatingStyle(new ToolboxTabFloatingStyle(this.resolveTabMaterialLevel(), this.bottomInsetVp))
    // 页签切换动画时长——动效设计的一部分，与 Motion.ets 的「结果出现 250ms」同量级。
    .animationDuration(MOTION_TAB_SWITCH)
    // ⚠️ 切页用 onTabBarClick，不要在 onTouch 里手动 changeIndex：
    // onTouch 是按压反馈用的（要拿 Down/Up 做缩放），两者混在一起会互相吞事件。
    .onTabBarClick((index: number): void => {
      this.tabsController.changeIndex(index);
    })
    .scrollable(true)
    .onChange((index: number): void => {
      this.homeTabIndex = index;
    })
  }

  /**
   * 悬浮底栏的材质等级：跟随框架的视觉设置存储键。
   *
   * 与框架 `NGFHdsImmersiveTabs` 同一来源（`ngf_visual_effects_effective_material_level`），
   * 这样「设置里的视觉强度」对首页底栏和框架其它组件是同一个值，不会各调各的。
   */
  private resolveTabMaterialLevel(): hdsMaterial.MaterialLevel {
    switch (this.tabMaterialLevel) {
      case hdsMaterial.MaterialLevel.EXQUISITE:
        return hdsMaterial.MaterialLevel.EXQUISITE;
      case hdsMaterial.MaterialLevel.GENTLE:
        return hdsMaterial.MaterialLevel.GENTLE;
      case hdsMaterial.MaterialLevel.SMOOTH:
        return hdsMaterial.MaterialLevel.SMOOTH;
      default:
        return hdsMaterial.MaterialLevel.ADAPTIVE;
    }
  }

  /** 第 index 个页签的标题；越界返回空串（页签条不会因此崩） */
  private tabTitleAt(index: number): string {
    const titles: Array<string> = this.tabTitles();
    return index < titles.length ? titles[index] : '';
  }

  /**
   * 第 index 个页签的内容。
   *
   * 0 号是「收藏与最近使用」，其余按分类取。
   */
  @Builder
  private buildTabBody(index: number) {
    Scroll() {
      Column({ space: 0 }) {
        if (index === 0) {
          this.buildStarredSection()
        } else {
          this.buildCategoryByIndex(index - 1)
        }
        Blank().height(32)
      }
      .width('100%')
      // bottom 留出浮动页签栏：barOverlap(true) 让栏浮在内容之上，
      // 不留白的话最后一行工具会被压在栏底下。
      .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: CONTENT_BOTTOM_INSET })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .onAreaChange((oldValue: Area, newValue: Area) => {
      const widthPx: number = Number(newValue.width);
      if (widthPx <= 0) {
        return;
      }
      const availableVp: number = widthPx - PAGE_PADDING * 2;
      if (Math.abs(availableVp - this.gridWidth) < 1) {
        return;
      }
      this.measureGrid(widthPx);
    })
  }

  /**
   * 单个页签（图标 + 文字 + 选中态 + 按压反馈）。
   *
   * ## 为什么带图标
   *
   * 结构对齐 NGF 来源仓 `MainMenuPage.buildTabItem`：底部页签由
   * **SymbolGlyph 图标 + 文字**组成，选中时图标放大加粗、两处同时换主色，
   * 并播放一次弹跳动效。此前只画一行文字，观感上就是「手搓的标签栏」，
   * 不像系统应用的页签——这正是本组件返工的原因。
   *
   * ## 为什么符号要由调用处传字面量
   *
   * `$r()` 由 ets-loader 在**构建期按字符串字面量**改写资源 ID，
   * 写成 `$r('sys.symbol.' + name)` 或 `$r(symbolName)` 都拿不到 Resource
   * （见 `ui/ToolSymbols.ets` 文件头）。所以符号一律在 `.tabBar()` 调用处
   * 写字面量，本方法只接已解析好的 `Resource`。
   */
  @Builder
  private buildTabItem(title: string, symbol: Resource, index: number) {
    Column({ space: 3 }) {
      SymbolGlyph(symbol)
        .fontSize(scaled(this.homeTabIndex === index ? 24 : 22))
        .fontWeight(this.homeTabIndex === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor([this.homeTabIndex === index
          ? colorOf(NGFColorToken.PRIMARY)
          : colorOf(NGFColorToken.ON_SURFACE_VARIANT)])
        .symbolEffect(new BounceSymbolEffect(EffectScope.WHOLE, EffectDirection.UP), this.homeTabIndex === index)
      Text(title)
        // 10vp 是「编解码与计算」这类五个字以上的分类名在五等分浮动栏里
        // 不被省略号截断的上限（11vp 时实测会截成「编解码与…」）。
        .fontSize(scaled(10))
        .fontWeight(this.homeTabIndex === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.homeTabIndex === index
          ? colorOf(NGFColorToken.PRIMARY)
          : colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 6, bottom: 6 })
    .scale(this.pressedTabIndex === index ? { x: 0.92, y: 0.92 } : { x: 1, y: 1 })
    .opacity(this.pressedTabIndex === index ? 0.8 : 1)
    .animation({ duration: MOTION_TAB_PRESS, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent): void => {
      if (event.type === TouchType.Down) {
        this.pressedTabIndex = index;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedTabIndex = -1;
      }
    })
    .accessibilityText(title)
    .accessibilityLevel('yes')
  }

  /** 0 号页签：收藏与最近使用 */
  @Builder
  private buildStarredSection() {
    Column({ space: 0 }) {
      this.buildSectionTitle($r('app.string.shell_section_favorites'))
      this.buildStrip(this.favoriteMetas())
      this.buildSectionTitle($r('app.string.shell_section_recent'))
      this.buildStrip(this.recentMetas())
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 按索引取某个分类的内容 */
  @Builder
  private buildCategoryByIndex(groupIndex: number) {
    Column({ space: 0 }) {
      this.buildGrid(this.groupsOfCurrentLocale()[groupIndex].tools)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  private groupsOfCurrentLocale(): Array<NGFToolCategoryGroup> {
    return groupToolsByCategory(toolRegistry, this.locale);
  }

  build() {
    // Navigation 是**根**：整个 App 只有一个导航栈。
    // 首页内容直接作为它的根页；工具页与关于页由 navDestination 分发（见 destBuilder）。
    HdsNavigation(this.pathStack) {
      // Stack：全屏沉浸底板铺底，内容叠在上面（NGF 原版 MainMenuPage 的同一结构）。
      // 顶部避让用**实测**的 this.topInsetVp（状态栏实测值 + 顶栏高度），
      // 不再写死数字——各机型状态栏高度不同，猜一个必然在部分设备上偏。
      Stack({ alignContent: Alignment.TopStart }) {
        this.buildFullscreenChrome()

        // ── 正文底 ──────────────────────────────────────────────
        // 从**顶栏下沿**开始铺主题背景（BACKGROUND）。
        //
        // 为什么必须有这一层：全屏底板是**恒深色**的，而正文用主题 Token 取色
        // （浅色主题下 ON_SURFACE_VARIANT 是深色字）。没有这层的话，
        // 「收藏」「最近使用」这些小标题就成了深色字压深色底——读不出来。
        //
        // height('100%') + margin(top)：底部会多出 topInsetVp 的长度，
        // 那部分在屏幕外，作背景无影响。
        Column() {}
          .width('100%')
          .height('100%')
          .margin({ top: this.topInsetVp })
          .backgroundColor(colorOf(NGFColorToken.BACKGROUND))

        Column({ space: 0 }) {
        // 搜索框固定在顶部：搜索时不该把输入框滚走
        //
        // 「关于」入口和搜索框**同一行**。之前它自己是独立一行、排在正文最上面，
        // 结果正好压在沉浸底板与正文底的分界线上，看着像浮在缝里（真机截图确认）。
        // 放到搜索框右侧后，它整个落在正文底内，位置稳定。
        Row({ space: 10 }) {
          Column({ space: 0 }) {
            this.buildSearchBox()
          }
          .layoutWeight(1)

          this.buildAboutEntry()
        }
        .width('100%')
        // top 要**多让 28**：框架顶栏的背景层带 `maskExtraHeight: 28`
        // （见 HdsNavigationSupport 的 NGFHdsNavigationBackgroundStyle），
        // 它比顶栏文字区高出 28vp。只让 topInsetVp 的话，
        // 首个内容元素（搜索框）会被那条背景压住——真机截图确认过。
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: TITLE_BAR_MASK_EXTRA })
        .alignItems(VerticalAlign.Center)

        if (this.keyword.trim().length > 0) {
          // 有关键词：只显示搜索结果（与首版行为一致）
          Scroll() {
            Column({ space: 0 }) {
              this.buildSearchResult()
              Blank().height(32)
            }
            .width('100%')
            .padding({ left: PAGE_PADDING, right: PAGE_PADDING })
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .layoutWeight(1)
          .align(Alignment.Top)
          .scrollBar(BarState.Auto)
          .edgeEffect(EdgeEffect.Spring)
          .onAreaChange((oldValue: Area, newValue: Area) => {
            const widthPx: number = Number(newValue.width);
            if (widthPx <= 0) {
              return;
            }
            const availableVp: number = widthPx - PAGE_PADDING * 2;
            if (Math.abs(availableVp - this.gridWidth) < 1) {
              return;
            }
            this.measureGrid(widthPx);
          })
        } else {
          // 无关键词：分类页签条 + 当前分类的内容
          this.buildHdsTabs()
        }
        }
        .width('100%')
        .height('100%')
        // 顶部避让：底板合成在内容之上，不避让会被压暗甚至挡住
        .padding({ top: this.topInsetVp })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(colorOf(NGFColorToken.BACKGROUND))
    }
    // 标题栏交给框架：标题/副标题、材质、滚动光效都由 NGFHdsTitleBarOptionsFactory 统一管，
    // 不再自绘（自绘的版本在浅色主题下还会和框架的白色标题打架）。
    // avoidLayoutSafeArea=true 让顶栏文字自己避开状态栏。
    // 第二阶段：buildAdaptive（框架 VENDORED 追记）——标题色跟主题，底色跟主题，
    // 不再「恒深底板 + 白字」。浅色下与系统应用一致（大标题同色一体）。
    .titleBar(NGFHdsTitleBarOptionsFactory.buildAdaptive(
      $r('app.string.shell_app_name'),
      $r('app.string.shell_app_subtitle'),
      titleBarBackground(this.isDark),
      titleBarScrolledBackground(this.isDark),
      titleBarTitleColor(this.isDark),
      titleBarSubtitleColor(this.isDark),
      hdsMaterial.MaterialLevel.EXQUISITE,
      true,
      false
    ))
    .titleMode(HdsNavigationTitleMode.FREE)
    .hideBackButton(true)
    // 允许内容铺到状态栏下面（配合窗口级沉浸，底板才延伸得上去）
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .mode(NavigationMode.Stack)
    .navDestination(this.destBuilder)
    // 从工具页返回根页时刷新。
    //
    // 为什么不用 onPageShow：迁到 NavPathStack 之后，工具页是**同一个页面**上的
    // destination，出栈时页面没有隐藏过，onPageShow 不触发——
    // 那样「用完工具回到首页，最近使用里没有刚用的那件」就会一直存在。
    // 导航栏重新可见 == 栈已回到根页。
    .onNavBarStateChange((isVisible: boolean): void => {
      if (isVisible) {
        this.locale = currentLocale();
        this.loadUserState();
      }
    })
  }

  /**
   * 路由分发：把导航栈里的名字映射成具体的 NavDestination。
   *
   * 参数是被框架门面包进 \`NGFNavigationParamEnvelope\` 的 JSON 字符串，
   * 不是原始对象——所以要经 \`payloadOf\` 解开再解析（解析逻辑在纯逻辑层，可单测）。
   */
  @Builder
  destBuilder(name: string, param: Object) {
    // HdsNavDestination 而不是裸 NavDestination（NGF 技能 skill-hds-page-design §2「形态 B」）。
    //
    // hideTitleBar(true)：本 App 的工具页/关于页自己带沉浸顶栏，标题由页面渲染。
    //   不隐藏的话会出现两层标题——而框架的 NGFHdsTitleBarOptionsFactory
    //   把标题色**写死成白色**，压在工具页的浅色主题内容上会读不出来。
    // ignoreLayoutSafeArea：允许内容铺到状态栏下面，与窗口级沉浸配套。
    if (name === TOOL_HOST_ROUTE_NAME) {
      HdsNavDestination() {
        ToolHostView({ toolId: readToolIdFromPayload(this.payloadOf(param)) })
      }
      // 顶栏由框架渲染：**返回按钮**、标题、副标题、材质、滚动光效都在这里，
      // 不需要自己画（上一版 hideTitleBar(true) 之后页面上根本没有返回入口）。
      // 背景色必须给深色——工厂把标题色写死成白色。
      // buildAdaptive：标题色/底色按主题（见 ImmersiveChrome 的四个取色函数）。
      // destBuilder 里拿不到组件的 this.isDark（它是 @Builder 方法，this 是本组件）——
      // 实际上可以，destBuilder 就是本组件的成员。直接用 this.isDark。
      .titleBar(NGFHdsTitleBarOptionsFactory.buildAdaptive(
        this.toolRouteTitle(param),
        this.toolRouteSubtitle(param),
        titleBarBackground(this.isDark),
        titleBarScrolledBackground(this.isDark),
        titleBarTitleColor(this.isDark),
        titleBarSubtitleColor(this.isDark),
        hdsMaterial.MaterialLevel.GENTLE,
        true,
        false
      ))
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .backgroundColor(titleBarBackground(this.isDark))
    } else if (name === ABOUT_ROUTE_NAME) {
      HdsNavDestination() {
        AboutView()
      }
      .titleBar(NGFHdsTitleBarOptionsFactory.buildAdaptive(
        $r('app.string.shell_about'),
        $r('app.string.shell_app_subtitle'),
        titleBarBackground(this.isDark),
        titleBarScrolledBackground(this.isDark),
        titleBarTitleColor(this.isDark),
        titleBarSubtitleColor(this.isDark),
        hdsMaterial.MaterialLevel.GENTLE,
        true,
        false
      ))
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .backgroundColor(titleBarBackground(this.isDark))
    }
  }

  /** 从框架的信封里取出 payloadJson；任何异常输入都返回空串 */
  private payloadOf(param: Object): string {
    if (param === undefined || param === null) {
      return '';
    }
    const envelope: NGFNavigationParamEnvelope = param as NGFNavigationParamEnvelope;
    const json: string = envelope.payloadJson;
    return (json === undefined || json === null) ? '' : json;
  }

  /** 工具页的标题：取不到元数据时留空，由「建设中」占位说明情况 */
  /** 工具副标题（工具页顶栏的第二行）。取不到就返回空串，框架会只显示主标题。 */
  private toolRouteSubtitle(param: Object): string {
    const id: string = readToolIdFromPayload(this.payloadOf(param));
    const meta: NGFToolMeta | null = toolRegistry.getMeta(id);
    if (meta === null) {
      return '';
    }
    // description 是 NGFLocalizedText（内容数据在纯数据层，不能用 $r()），
    // 所以这里按当前语言取一次字符串。
    const description: NGFLocalizedText | undefined = meta.description;
    if (description === undefined) {
      return '';
    }
    return description.forLocale(this.locale);
  }

  private toolRouteTitle(param: Object): string {
    const id: string = readToolIdFromPayload(this.payloadOf(param));
    const meta: NGFToolMeta | null = toolRegistry.getMeta(id);
    if (meta === null) {
      return '';
    }
    return ToolContext.fromMeta(meta, this.locale).toolName;
  }

  /**
   * 主体：有关键词时只显示搜索结果，否则显示收藏/最近使用/全部分类。
   *
   * 用 @Builder 而不是在 build 里写 if/else：build 保持成一份结构清单，
   * 谁都能一眼看出页面由哪几块构成。
   */
  @Builder
  private buildBody() {
    if (this.keyword.trim().length > 0) {
      this.buildSearchResult()
    } else {
      this.buildDefaultSections()
    }
  }

  @Builder
  private buildSearchResult() {
    Column({ space: 0 }) {
      this.buildSectionTitle($r('app.string.shell_section_search'))
      if (this.hitMetas().length > 0) {
        this.buildGrid(this.hitMetas())
      } else {
        this.buildEmptyHint($r('app.string.shell_empty_no_match'))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildDefaultSections() {
    Column({ space: 0 }) {
      if (this.favoriteMetas().length > 0) {
        this.buildSectionTitle($r('app.string.shell_section_favorites'))
        this.buildStrip(this.favoriteMetas())
      }
      if (this.recentMetas().length > 0) {
        this.buildSectionTitle($r('app.string.shell_section_recent'))
        this.buildStrip(this.recentMetas())
      }
      this.buildAllTools()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 全部工具：按产品定义稿 §四 的固定分类顺序铺开 */
  @Builder
  private buildAllTools() {
    Column({ space: 0 }) {
      if (toolRegistry.totalCount() === 0) {
        this.buildEmptyHint($r('app.string.shell_empty_catalog_loading'))
      } else {
        ForEach(groupToolsByCategory(toolRegistry, this.locale), (group: NGFToolCategoryGroup) => {
          this.buildCategoryGroup(group)
        }, (group: NGFToolCategoryGroup) => group.category)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildCategoryGroup(group: NGFToolCategoryGroup) {
    Column({ space: 0 }) {
      this.buildSectionTitle(group.label)
      this.buildGrid(group.tools)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 自适应网格。
   *
   * 用 `Flex(wrap)` 而不是 `Grid`：`Grid` 的列数需要传
   * `GridRowColumnOption`（`{ xs, sm, md, lg }`），那是**媒体断点**口径，
   * 与「按可用宽度算列数」是两套模型；而我们已经把列数算成了纯函数，
   * 用 Flex 换行才能让那份计算真正生效（否则断点会覆盖它，两边打架）。
   */
  @Builder
  private buildGrid(tools: Array<NGFToolMeta>) {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
      ForEach(tools, (meta: NGFToolMeta) => {
        ToolCard({ meta: meta, cardWidth: this.cardWidth, gap: CARD_GAP, locale: this.locale })
      }, (meta: NGFToolMeta) => meta.id)
    }
    .width('100%')
    .margin({ bottom: 4 })
  }

  /** 横向条带（收藏 / 最近使用）：卡片更小，一眼可及 */
  @Builder
  private buildStrip(tools: Array<NGFToolMeta>) {
    Scroll() {
      Row({ space: 10 }) {
        ForEach(tools, (meta: NGFToolMeta) => {
          ToolChip({ meta: meta, locale: this.locale })
        }, (meta: NGFToolMeta) => meta.id)
      }
      .padding({ right: 4 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  /**
   * 「关于」入口。
   *
   * ⚠️ 这里**不再渲染产品名**——标题已由框架的 `NGFHdsTitleBarOptionsFactory`
   * 统一渲染（见 build() 的 .titleBar）。自绘一份会和框架的标题重复，
   * 而且框架把标题色写死成白色，自绘的深色字在深色底板上会读不出来。
   */
  /**
   * 「关于」入口（**只出图标**，由调用方决定摆在哪一行）。
   *
   * 这是「看一眼就走」的信息类页面，所以不塞进工具网格——那会占掉一个
   * 本该给工具的位置。当前摆位在搜索框右侧。
   */
  @Builder
  private buildAboutEntry() {
    SymbolGlyph($r('sys.symbol.info_circle'))
      .fontSize(scaled(24))
      .fontColor([colorOf(NGFColorToken.ON_SURFACE_VARIANT)])
      .onClick(() => {
        openAboutPage();
      })
      .accessibilityText($r('app.string.shell_about'))
      .accessibilityLevel('yes')
  }

  /** 搜索框 */
  @Builder
  private buildSearchBox() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(scaled(18))
        .fontColor([colorOf(NGFColorToken.ON_SURFACE_VARIANT)])
      TextInput({ text: this.keyword, placeholder: $r('app.string.shell_search_placeholder') })
        .layoutWeight(1)
        .backgroundColor(Color.Transparent)
        .padding(0)
        .fontSize(scaled(15))
        .placeholderFont({ size: 15 })
        .onChange((value: string) => {
          this.keyword = value;
        })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(colorOf(NGFColorToken.SURFACE))
    .borderRadius(12)
    .margin({ bottom: 8 })
  }

  /** 分组小标题 */
  @Builder
  private buildSectionTitle(label: ResourceStr) {
    Text(label)
      .fontSize(scaled(14))
      .fontWeight(FontWeight.Medium)
      .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      .width('100%')
      .margin({ top: 16, bottom: 8 })
  }

  /** 空态提示 */
  @Builder
  private buildEmptyHint(hint: ResourceStr) {
    Text(hint)
      .fontSize(scaled(14))
      .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      .width('100%')
      .padding({ top: 8, bottom: 8 })
  }
}

/**
 * 工具卡片（网格用）。
 *
 * 单独成组件而不是写成内联布局：同一张卡片在「搜索结果」与「分类网格」
 * 两处出现，内联会导致样式各写一遍，将来改一处漏一处。
 */
@Component
struct ToolCard {
  /** 订阅主题深浅；本字段本身不用，作用是在主题切换时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  meta: NGFToolMeta = NGFToolMeta.empty();
  cardWidth: number = 156;
  gap: number = CARD_GAP;
  /** 当前语言；名称与描述按它取。由页面传入，卡片自己不去读设备语言 */
  locale: string = FALLBACK_LOCALE;

  build() {
    Column({ space: 6 }) {
      Row() {
        // 图标资源必须来自**字面量表**，不能拼字符串：
        // $r() 由 ets-loader 在构建期按字面量静态改写成资源 ID，
        // 拼接表达式无法被改写（详见 ui/ToolSymbols.ets 的说明）。
        SymbolGlyph(toolSymbolOf(this.meta.id))
          .fontSize(scaled(20))
          .fontColor([toolRegistry.isImplemented(this.meta.id)
            ? colorOf(NGFColorToken.PRIMARY)
            : colorOf(NGFColorToken.ON_SURFACE_VARIANT)])
        Blank()
        // 需要联网的工具在网格里就有记号，用户点进去之前就能看见
        if (this.meta.usesNetwork) {
          SymbolGlyph(NETWORK_BADGE_SYMBOL)
            .fontSize(scaled(14))
            .fontColor([colorOf(NGFColorToken.WARNING)])
        }
      }
      .width('100%')

      Text(this.meta.name.forLocale(this.locale))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Text(toolRegistry.isImplemented(this.meta.id)
        ? this.meta.description.forLocale(this.locale)
        : $r('app.string.shell_under_construction'))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .lineHeight(16)
        .width('100%')
    }
    // 卡片宽度减去间距：间距由每张卡片自己的右/下 margin 承担，
    // 这样 Flex 换行时最后一行与中间行左边缘仍然对齐。
    .width(this.cardWidth - this.gap)
    .height(104)
    .padding(12)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(colorOf(NGFColorToken.SURFACE))
    .borderRadius(12)
    .margin({ right: this.gap, bottom: this.gap })
    .onClick(() => {
      openTool(this.meta.id);
    })
  }
}

/**
 * 工具小卡（横向条带用）。
 *
 * 与 {@link ToolCard} 的区别：条带里只有图标 + 名称。
 * 用户在横向滚动时是在「快速找刚才那个」，不需要读描述。
 */
@Component
struct ToolChip {
  /** 订阅主题深浅；本字段本身不用，作用是在主题切换时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  meta: NGFToolMeta = NGFToolMeta.empty();
  locale: string = FALLBACK_LOCALE;

  build() {
    Column({ space: 6 }) {
      SymbolGlyph(toolSymbolOf(this.meta.id))
        .fontSize(scaled(20))
        .fontColor([colorOf(NGFColorToken.PRIMARY)])
      Text(this.meta.name.forLocale(this.locale))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(84)
    .padding({ top: 10, bottom: 10 })
    .backgroundColor(colorOf(NGFColorToken.SURFACE))
    .borderRadius(12)
    .onClick(() => {
      openTool(this.meta.id);
    })
  }
}
