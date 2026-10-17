/**
 * 沉浸式顶栏的配置（**UI 层**唯一出口）。
 *
 * ## 它解决什么问题
 *
 * 框架的 \`NGFImmersiveTopChromeUnderlay\` 是**装饰性底板**（渐变 + 光晕 + 材质模糊），
 * 不是标题栏——标题仍由 \`ToolScaffold\` 自己渲染，底板只是背景。
 *
 * 它自带的 preset 是**深蓝**配色（\`#07101E\` / \`#0C2341\`），为深色沉浸式界面设计。
 * 本 App 跟随系统深浅色，浅色主题下直接用它会在白底页面上糊一块深蓝。
 * 所以这里按主题给两套渐变，而不是各处硬编码。
 *
 * ## 一个必须记住的避让陷阱（框架注释里的实测结论）
 *
 * 底板的 \`expandSafeArea([SYSTEM], [TOP])\` 让它**向状态栏方向扩展**，
 * 所以它实际覆盖的高度是 \`底板高度 + 顶部安全区\`；
 * **而且它合成在内容之上**——落在这一带里的内容会被压暗甚至挡住。
 *
 * 框架自己的注释记着：曾经三个页面都写死避让 92（= preset 的 contentTopInset 默认值），
 * 于是首个内容元素整块落在覆盖带里，表现为「顶部未正确避让、按钮被挡住」。
 *
 * 所以内容避让必须用 \`ngfImmersiveContentTop(底板高度, 顶部安全区)\` 算，不能猜数字。
 *
 * @module ui/ImmersiveChrome
 */

import {
  ngfImmersiveContentTop,
  NGFImmersiveTopChromePresetFactory,
  NGFImmersiveTopChromeSpec
} from 'ngf_framework';

/**
 * 底板高度（vp）。与框架 preset 的默认值一致。
 *
 * 改这个值**必须**同时确认 {@link chromeContentTop} 仍被用于内容避让——
 * 底板变高而避让没变，内容就会被压暗。
 */
/**
 * 全屏沉浸底板的配色（照搬 NGF 原版 `MainMenuPage.buildFullscreenBackgroundUnderlay`）。
 *
 * ⚠️ 这是**恒深色**的，不跟随系统浅色主题。原因不是偷懒：
 * 标题要交给框架的 `NGFHdsTitleBarOptionsFactory` 渲染，而它把标题色
 * **写死成白色**（`app.color.text_white`）。顶栏要放白字，底色就必须恒深。
 * 原版主页也是这么做的。
 */
export const FULLSCREEN_CHROME: Array<string> = [
  '#07101E', // 渐变起点
  '#0C2341', // 0.28
  '#143964', // 0.58
  '#0B2747', // 0.82
  '#0A1626'  // 终点
];

/** 光晕主色（ARGB，末两位是 alpha）。 */
export const FULLSCREEN_GLOW_PRIMARY: string = '#2854F0E8';

/** 光晕辅色。 */
export const FULLSCREEN_GLOW_SECONDARY: string = '#32A4F2D8';

export const CHROME_UNDERLAY_HEIGHT: number = 88;

/**
 * 顶部系统安全区高度（vp）。
 *
 * ⚠️ 这个值是**框架注释里的实机测量结果**（168 + 28 = 196vp，
 * 像素剖面在 y≈392px 处从渐变突降到页面底色，与该值吻合）。
 *
 * 本机没有可用的真机，无法重新测量，所以先用它。
 * 各机型状态栏高度不同：**真机回归时如果发现内容被挡或被顶得太低，改这里**。
 */
export const TOP_SAFE_INSET: number = 44;

/**
 * **首页**的底板高度（vp）。比工具页矮。
 *
 * 工具页顶部要放「返回 + 工具名 + 副标题 + 历史按钮」，所以用框架 preset 的 168；
 * 首页顶部只有「标题 + 副标题 + 搜索框」，用 168 会在标题上方留一大段空渐变。
 * 这里按首页实际的顶栏高度给一个更矮的值。
 *
 * ⚠️ 真机回归时若发现搜索框被渐变压住或整体偏高/偏低，**改这个值**
 * （{@link homeChromeContentTop} 会跟着变，不用改两处）。
 */
export const HOME_CHROME_UNDERLAY_HEIGHT: number = 132;

/**
 * 内容区要向下避让的距离。
 *
 * 用框架的函数算，而不是写死数字：写死正是框架注释里记录的那次事故。
 */
export function homeChromeContentTop(): number {
  return ngfImmersiveContentTop(HOME_CHROME_UNDERLAY_HEIGHT, TOP_SAFE_INSET);
}

/**
 * 首页底板的配色。与工具页**同一套**配色，只是高度不同——
 * 两处如果各调各的色，同一个 app 里会出现两种顶栏色。
 */
export function homeChromeSpec(isDark: boolean): NGFImmersiveTopChromeSpec {
  if (isDark) {
    return NGFImmersiveTopChromePresetFactory.build(
      '#07101E', '#0C2341', '#0A1626', '#2854F0E8', '#32A4F2D8',
      HOME_CHROME_UNDERLAY_HEIGHT
    );
  }
  return NGFImmersiveTopChromePresetFactory.build(
    '#E8F0FE', '#F1F6FF', '#FBFDFF', '#1F0962F2', '#1A2F9BE0',
    HOME_CHROME_UNDERLAY_HEIGHT
  );
}

/**
 * 没有底板的页面（关于页、工具页占位态）在**全屏布局**下的最小顶部避让。
 *
 * 开了窗口级沉浸之后，内容不再自动躲开状态栏；这些页面没有渐变可以叠，
 * 所以只需让开状态栏那一条，再加一点呼吸空间。
 */
export function barePageContentTop(): number {
  return TOP_SAFE_INSET + 12;
}

export function chromeContentTop(): number {
  return ngfImmersiveContentTop(CHROME_UNDERLAY_HEIGHT, TOP_SAFE_INSET);
}

/**
 * 工具页底板配色（**第二阶段起跟随主题**，2026-10-17）。
 *
 * 之前恒深：那时标题交给框架 build() 渲染、标题色写死白字，底色被迫恒深。
 * 现在框架加了 buildAdaptive()（见 ngf_framework/VENDORED.md 同日追记），
 * 标题色可配，底板不必再为「白字」而恒深——这里改回真正按主题取值：
 * 深色用框架 preset 的深蓝（那套本来就是为深色沉浸界面调的），
 * 浅色用低饱和蓝白渐变（光晕压低，避免白底上糊出色团）。
 */
export function chromeSpecFor(isDark: boolean): NGFImmersiveTopChromeSpec {
  if (isDark) {
    return NGFImmersiveTopChromePresetFactory.build(
      FULLSCREEN_CHROME[0], FULLSCREEN_CHROME[1], FULLSCREEN_CHROME[4],
      FULLSCREEN_GLOW_PRIMARY, FULLSCREEN_GLOW_SECONDARY,
      CHROME_UNDERLAY_HEIGHT
    );
  }
  return NGFImmersiveTopChromePresetFactory.build(
    '#E8F0FE', '#F1F6FF', '#FBFDFF', '#1F0962F2', '#1A2F9BE0',
    CHROME_UNDERLAY_HEIGHT
  );
}

/** 标题栏（HdsNavDestination）在**未滚动**时的背景色，按主题。 */
export function titleBarBackground(isDark: boolean): string {
  return isDark ? FULLSCREEN_CHROME[0] : '#E8F0FE';
}

/** 标题栏在**滚动后**的背景色：与未滚动同色系、略深一档，配合滚动模糊。 */
export function titleBarScrolledBackground(isDark: boolean): string {
  return isDark ? '#0B2747' : '#F1F6FF';
}

/** 标题栏标题/副标题颜色，按主题（替代框架写死的 text_white）。 */
export function titleBarTitleColor(isDark: boolean): string {
  return isDark ? '#FFFFFF' : '#18202B';
}

export function titleBarSubtitleColor(isDark: boolean): string {
  return isDark ? '#E6FFFFFF' : '#5C6B7E';
}
