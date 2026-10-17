/**
 * 主题与颜色 Token 的**唯一出口**（UI 层）。
 *
 * ## 为什么必须走框架，而不是自建 color.json
 *
 * 首版开发时我自建了两份 \`resources/base|dark/element/color.json\`（14 个键、494 处引用），
 * 还写了 \`check-theme-contrast.mjs\` 去审计它——**但产品定义稿 §3.1 第 56 行写的是
 * 「深浅双主题（uiTheme）」**。框架的 uiTheme 提供的是一套语义 Token（每个带 light/dark
 * 两值）外加运行时可切换的 ThemeManager，自建 color.json 无论怎么审计都做不到其中任何一件。
 *
 * ## 主题是怎么生效的（这一点决定了页面怎么写）
 *
 * \`ngfThemeManagerFacade.setThemeOverride()\` **只写 AppStorage + 通知回调，
 * 不调 setColorMode**——所以 \`$r('app.color.x')\` 这种编译期资源 ID **不会**跟随应用内
 * 主题覆盖（它只跟随系统深浅色）。框架的设计是**运行时 Token**：
 * 取色时现算 \`resolveColor()\`，而它内部读 \`isDarkMode()\`。
 *
 * 于是页面必须做两件事：
 * 1. 用 \`colorOf(NGFColorToken.X)\` 取色，而不是 \`$r('app.color.x')\`；
 * 2. 声明 \`@StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;\`
 *    ——主题一变这个值就变，组件自动重渲染，\`colorOf()\` 随之取到新色。
 *
 * 第 2 条是本方案能成立的关键：没有它，切主题时界面不会刷新。
 *
 * @module ui/ThemeSource
 */

import { toolboxPalette } from '../core/ToolboxPalette';
import { applyWindowChrome } from './WindowChrome';
import {
  ngfColorTokenProviderFacade,
  ngfThemeManagerFacade,
  NGFColorToken,
  NGFColorValue,
  NGFThemeMode
} from 'ngf_framework';

/**
 * 「当前是否深色」的 AppStorage 键。
 *
 * 页面用 \`@StorageProp(TOOLBOX_DARK_KEY)\` 订阅它来触发重渲染。
 * 值为 true 表示深色。**必须用这个常量**，不要自己写字符串字面量——
 * 拼错不会报错，只会表现为「切主题界面不刷新」。
 */
export const TOOLBOX_DARK_KEY: string = 'toolbox_is_dark';

/** 读取失败时的回退：跟随系统 */
export const FALLBACK_THEME_MODE: NGFThemeMode = NGFThemeMode.AUTO;

/**
 * 把工具箱的调色板注册进框架 Token 体系。
 *
 * ## 为什么必须注册
 *
 * 框架 \`registerDefaults()\` 注册的是 **MD3 基准紫 \`#6750A4\`**——
 * 那是 Material You 的默认色，不是本 App 的蓝 \`#0962F2\`。
 * 不覆盖就会整个 App 变成紫色，而且不会有人报错。
 *
 * 色值直接来自原先两份 color.json 的 light/dark 列，一一对应，
 * 迁移期间两套并存也不会出现颜色不一致。
 */
function registerToolboxPalette(): void {
  // 色值来自 core/ToolboxPalette（纯数据）——对比度门禁审计的是**同一份**，
  // 这样「门禁通过」才真的蕴含「界面上的色是达标的」。
  const palette: Array<NGFColorValue> = toolboxPalette();
  for (let i: number = 0; i < palette.length; i++) {
    ngfColorTokenProviderFacade.registerColor(palette[i]);
  }
}

/** 把「当前是否深色」同步到 AppStorage，供页面的 @StorageProp 订阅 */
function syncDarkToStorage(): void {
  const isDark: boolean = ngfThemeManagerFacade.isDarkMode();
  AppStorage.setOrCreate<boolean>(TOOLBOX_DARK_KEY, isDark);
  // 状态栏/导航栏的图标颜色也要跟着主题走（浅色主题下白图标看不见）。
  // 这里调是安全的：窗口还没绑定时门面只是记下策略，
  // 等 EntryAbility 里 bindWindowStage() 之后会自动重新应用一次。
  applyWindowChrome(isDark);
}

/**
 * 初始化主题。**App 启动时调一次**（EntryAbility.onCreate）。
 *
 * 顺序不能颠倒：先 \`registerDefaults()\` 铺满 20 个基准 Token，
 * 再用本 App 调色板覆盖——反过来的话没被覆盖的 Token 会是未注册状态，
 * \`resolveColor()\` 会返回黑色 \`#000000\`。
 */
export function initializeTheme(): void {
  try {
    ngfColorTokenProviderFacade.registerDefaults();
    registerToolboxPalette();
    ngfThemeManagerFacade.initializeDefaults();
    syncDarkToStorage();
    // 主题一变就刷新 AppStorage，页面据此重渲染。
    ngfThemeManagerFacade.onThemeChanged((mode: NGFThemeMode): void => {
      syncDarkToStorage();
    });
  } catch (error) {
    // 主题初始化失败不该让 App 起不来：退化成系统默认外观即可。
  }
}

/** 当前主题模式（LIGHT / DARK / AUTO） */
export function currentThemeMode(): NGFThemeMode {
  try {
    return ngfThemeManagerFacade.getCurrentTheme();
  } catch (error) {
    return FALLBACK_THEME_MODE;
  }
}

/** 当前是否深色 */
export function isDarkTheme(): boolean {
  try {
    return ngfThemeManagerFacade.isDarkMode();
  } catch (error) {
    return false;
  }
}

/** 手动指定主题（设置页的「浅色/深色/跟随系统」） */
export function setThemeMode(mode: NGFThemeMode): void {
  try {
    ngfThemeManagerFacade.setThemeOverride(mode);
  } catch (error) {
  }
}

/** 恢复跟随系统 */
export function resetThemeToSystem(): void {
  try {
    ngfThemeManagerFacade.clearThemeOverride();
  } catch (error) {
  }
}

/**
 * 系统深浅色变化时由 UI 层转发进来（EntryAbility.onConfigurationUpdate）。
 *
 * 必须转发：框架不会自己去读系统配置，它等调用方告诉它。
 */
export function notifySystemColorMode(colorMode: number): void {
  try {
    ngfThemeManagerFacade.handleSystemColorModeChanged(colorMode);
    syncDarkToStorage();
  } catch (error) {
  }
}

/**
 * Token → 颜色值。
 *
 * 返回 string 而不是 Resource：Token 表在运行时可换，编译期静态资源 ID 表达不了。
 * ArkUI 的 \`ResourceColor\` 接受 string，直接传给 \`.fontColor()\` / \`.backgroundColor()\` 均可。
 *
 * 取不到时返回空串，由 ArkUI 用它自己的默认值——比返回黑色安全：
 * 黑色可能让深色主题下的文字彻底看不见。
 */
export function colorOf(token: NGFColorToken): string {
  try {
    return ngfColorTokenProviderFacade.resolveColor(token);
  } catch (error) {
    return '';
  }
}
