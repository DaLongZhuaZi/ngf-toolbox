/**
 * 窗口级沉浸与**动态安全区**（app 侧唯一出口）。
 *
 * ## 这个文件是从哪来的
 *
 * 它不是自己设计的，是 **NGF 来源仓**里
 * `airwavefootprints/entry/src/main/ets/pages/ngf/NGFPageWindowSupport.ets` 的移植。
 * 按 `.rules/skill-hds-page-design.md`（HDS 页面设计技能 §5「安全区处理规范」）与
 * `MainMenuPage` 的实际做法改写成工具箱的页面名与配色。
 *
 * ⚠️ **上一个版本是自造的，而且错了两处**：
 *
 * 1. 用写死的 `TOP_SAFE_INSET = 28` 当状态栏高度——各机型不一样，
 *    正确做法是 {@link loadDynamicInsets} 去问系统（`getWindowAvoidArea` + `px2vp`）。
 * 2. 用 `ngfPlatformWindowManagerFacade.activatePage()` 应用策略——
 *    原版用的是 `ngfPagePolicyHostFacade.applyPolicy()` + `reapplyPolicy()`。
 *
 * ## 为什么必须开窗口级沉浸
 *
 * ArkUI 默认把窗口布局在**状态栏下方**，状态栏区域显示窗口底色。
 * 于是底板的 `expandSafeArea([SYSTEM], [TOP])` 没有可扩展的空间——
 * 表现就是「状态栏一条底色，怎么调底板都不沉浸」。
 *
 * @module ui/WindowChrome
 */

import { window } from '@kit.ArkUI';
import {
  logger,
  NGFDisplayMode,
  NGFPageWindowProfile,
  NGFWindowOrientationPreference,
  NGFWindowSystemBarPolicy,
  NGFWindowSystemBarStyle,
  ngfPagePolicyHostFacade,
  ngfPlatformWindowManagerFacade
} from 'ngf_framework';

const TAG: string = 'ToolboxWindowChrome';

/** 首页（HdsNavigation 根页）。名字要与页面名一致，策略按它解析。 */
export const WINDOW_PAGE_HOME: string = 'toolbox.home';

/** 工具页。
 *
 * 工具箱是**单窗口单 @Entry 页面**应用（工具页与关于页都是同一个页面上的
 * NavDestination），所以窗口策略其实只有「首页」与「内容页」两种。
 * 拆成两个名字是为了让后续要给内容页单独调策略时不必改调用点。 */
export const WINDOW_PAGE_CONTENT: string = 'toolbox.content';

/**
 * 首页顶栏高度（vp）。
 *
 * 取自 `MainMenuPage` 的注释：HdsNavigation 的 FREE 标题模式 =
 * 状态栏 + 大标题 + 副标题 + 边距 ≈ 108vp。
 * 实际避让 = **状态栏实测值** + 这个高度（见 {@link loadDynamicInsets}）。
 */
export const HOME_TITLE_BAR_HEIGHT: number = 108;

/** 内容页顶栏高度（vp）：小标题比首页矮。 */
export const CONTENT_TITLE_BAR_HEIGHT: number = 56;

/**
 * 底部留白（vp）：浮动页签栏 + 手势条。
 *
 * 原版 MainMenuPage 用的是 76——但那是**纯文字**页签。
 * 本仓的页签带图标（24vp）+ 文字（10vp）+ 上下 padding，栏本身更高，
 * 76 实测会让最后一排工具卡片被悬浮栏压住（真机「网络」页签一眼可见）。
 * 104 是实测能露出整行卡片的取值。
 */
export const CONTENT_BOTTOM_INSET: number = 104;

/**
 * 内容页（工具页 / 关于页）顶部要预留的高度（vp）。
 *
 * 组成：框架 HdsNavDestination 顶栏文字区（≈56）+ 它背景层的 `maskExtraHeight`（28）
 * + 一点呼吸空间。
 *
 * **不够会让页面自己的首个元素被顶栏压住**——关于页就踩过：
 * 原先只让 `状态栏 + 12`，真机上「NGF 开发者工具箱」被顶栏切掉一半。
 */
export const CONTENT_TOP_RESERVE: number = 88;

/** 状态栏/导航栏透明：内容透上来，这才是「沉浸」。 */
const BAR_TRANSPARENT: string = '#00000000';

/**
 * 系统栏图标色：**恒用浅色（白）**。
 *
 * 理由：本 App 采用 NGF 原版主页的设计——**顶栏恒为深色沉浸底**
 * （深蓝渐变 + 光晕），标题由 {@link ./ImmersiveChrome} 交给
 * `NGFHdsTitleBarOptionsFactory` 渲染，而那个工厂把标题色**写死成白色**。
 * 顶栏既然恒深，系统栏图标就必须恒浅——否则浅色主题下白图标压在深蓝底上等于没有。
 */
const ICON_ON_CHROME: string = '#FFFFFFFF';

/** 上一次注册配置时的主题，用来判断要不要重注册。 */
let registeredForDark: boolean | null = null;

/** 绑定窗口阶段。必须在 `onWindowStageCreate` 调用——门面要靠它拿 mainWindow。 */
export function bindWindowChrome(windowStage: window.WindowStage): void {
  ngfPlatformWindowManagerFacade.bindWindowStage(windowStage);
}

/**
 * 应用窗口级沉浸策略。
 *
 * **可重复调用**：主题切换后要再调一次换系统栏图标色；
 * 页面切换后要按新页面名再调一次（顶栏高度不同）。
 *
 * @param isDark 当前是否深色主题（只影响重注册的判定，系统栏图标恒浅色）
 */
export function applyWindowChrome(isDark: boolean): void {
  ensureProfilesRegistered(isDark);
  ngfPagePolicyHostFacade.applyPolicy(WINDOW_PAGE_HOME);
  ngfPagePolicyHostFacade.reapplyPolicy(WINDOW_PAGE_HOME);
}

/**
 * 读取**真实的**状态栏与导航栏高度（vp）。
 *
 * 这是替代写死数字的关键：各机型状态栏高度不同，
 * 猜一个值必然在部分设备上偏。
 *
 * 拿不到时回退到调用方给的默认值——**不是静默失败**，会记一条 warn。
 *
 * @param uiCtx          UIContext（组件里用 `this.getUIContext()`）
 * @param fallbackTop    取不到时的顶部安全区
 * @param fallbackBottom 取不到时的底部安全区
 * @param callback       拿到后回调（可能立刻回调，也可能异步）
 */
export function loadDynamicInsets(
  uiCtx: UIContext | undefined,
  fallbackTop: number,
  fallbackBottom: number,
  callback: (top: number, bottom: number) => void
): void {
  if (!uiCtx) {
    callback(fallbackTop, fallbackBottom);
    return;
  }
  const hostCtx = uiCtx.getHostContext();
  if (!hostCtx) {
    callback(fallbackTop, fallbackBottom);
    return;
  }
  window.getLastWindow(hostCtx).then((lastWindow: window.Window): void => {
    const topArea: window.AvoidArea = lastWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    const bottomArea: window.AvoidArea = lastWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
    const top: number = uiCtx.px2vp(topArea.topRect.height);
    const bottom: number = uiCtx.px2vp(bottomArea.bottomRect.height);
    logger.info(TAG, '实测安全区: top=' + String(top) + ', bottom=' + String(bottom));
    callback(top, bottom);
  }).catch((err: Error): void => {
    logger.warn(TAG, '读取安全区失败，用默认值: ' + err.message);
    callback(fallbackTop, fallbackBottom);
  });
}

/** 按主题注册两条页面策略。主题变了会重注册。 */
function ensureProfilesRegistered(isDark: boolean): void {
  if (registeredForDark === isDark) {
    return;
  }
  const style: NGFWindowSystemBarStyle = buildSystemBarStyle(isDark);
  const profiles: Array<NGFPageWindowProfile> = [
    buildProfile(WINDOW_PAGE_HOME, style),
    buildProfile(WINDOW_PAGE_CONTENT, style)
  ];
  for (let i: number = 0; i < profiles.length; i++) {
    ngfPlatformWindowManagerFacade.registerPageProfile(profiles[i]);
  }
  registeredForDark = isDark;
  logger.info(TAG, '注册窗口策略: 深色=' + String(isDark));
}

/**
 * 系统栏样式：两条系统栏**透明**（沉浸），图标色跟随主题。
 *
 * ⚠️ `isStatusBarLightIcon` 里的 light 指「图标是浅色的」，语义容易反过来，
 * 所以它必须和 `statusBarContentColor` **一起**设，别只改一个。
 */
function buildSystemBarStyle(isDark: boolean): NGFWindowSystemBarStyle {
  const style = new NGFWindowSystemBarStyle();
  style.enabled = true;
  style.statusBarColor = BAR_TRANSPARENT;
  style.navigationBarColor = BAR_TRANSPARENT;
  style.statusBarContentColor = ICON_ON_CHROME;
  style.navigationBarContentColor = ICON_ON_CHROME;
  style.isStatusBarLightIcon = true;
  style.isNavigationBarLightIcon = true;
  style.enableStatusBarAnimation = true;
  style.enableNavigationBarAnimation = true;
  return style;
}

function buildProfile(pageName: string, style: NGFWindowSystemBarStyle): NGFPageWindowProfile {
  // IMMERSIVE_WITH_BARS = 布局全屏 + 两条系统栏透明可见。
  // 不是 FULL_IMMERSIVE（那会连状态栏一起隐藏，用户看不到时间和电量），
  // 也不是 STATUS_SAFE_BOTTOM_IMMERSIVE（那会藏掉导航栏）。
  const policy = new NGFWindowSystemBarPolicy(true, true, true, true, style);
  return new NGFPageWindowProfile(
    pageName,
    NGFDisplayMode.IMMERSIVE_WITH_BARS,
    NGFWindowOrientationPreference.UNSPECIFIED,
    true,
    policy,
    0
  );
}
