/**
 * 关怀模式（字体缩放）的**唯一出口**（UI 层）。
 *
 * ## 关怀模式在框架里的位置
 *
 * 注意它在 **uiTheme** 层，不在 deviceAwareness——按「字体」去找很容易找错地方。
 * 框架给了完整一套：\`FONT\` has \`NGFFontScaleLevel\`（SMALL/NORMAL/LARGE/EXTRA_LARGE）+ 自定义倍率
 * + 订阅变化，覆盖系统「关怀模式 / 大字体」的需求。
 *
 * ## 为什么要有 \`scaled()\` 这个入口
 *
 * 首版所有页面都写死 \`fontSize(14)\` 这类字面量，系统放大字体时**完全不跟**。
 * 有了 \`scaled(14)\`，页面只要把字面量换成它，关怀模式就自动生效——
 * 这是「从底层支持」和「页面级打补丁」的区别。
 *
 * @module ui/FontScaleSource
 */

import { ngfFontScaleManagerFacade, NGFFontScaleLevel } from 'ngf_framework';

/**
 * 当前字体缩放倍率的 AppStorage 键。
 *
 * 与主题同理：\`scaled()\` 是**运行时计算**，档位变了它不会自己通知 ArkUI。
 * 页面要声明 \`@StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;\`
 * 来触发重渲染——那个字段本身不用，它的作用是让 build() 重跑一遍。
 *
 * **必须用这个常量**，不要自己写字符串字面量：拼错不报错，
 * 只表现为「切了字号界面没反应」。
 */
export const TOOLBOX_FONT_SCALE_KEY: string = 'toolbox_font_scale';

/** 读取失败时的回退倍率：1.0 = 不缩放 */
export const FALLBACK_FONT_SCALE: number = 1.0;

/** 把当前倍率同步进 AppStorage，供页面的 @StorageProp 订阅 */
function syncScaleToStorage(): void {
  AppStorage.setOrCreate<number>(TOOLBOX_FONT_SCALE_KEY, currentFontScale());
}

/**
 * 初始化关怀模式。**App 启动时调一次**（EntryAbility.onCreate）。
 *
 * 做两件事：把当前倍率写进 AppStorage，并订阅后续变化。
 * 少了订阅，用户在设置页调完字号，已经打开的页面不会跟着变。
 */
export function initializeFontScale(): void {
  try {
    syncScaleToStorage();
    ngfFontScaleManagerFacade.onScaleChanged((scale: number): void => {
      AppStorage.setOrCreate<number>(TOOLBOX_FONT_SCALE_KEY, scale);
    });
  } catch (error) {
    // 初始化失败退化成不缩放，不该让 App 起不来
  }
}

/** 当前字体缩放倍率 */
export function currentFontScale(): number {
  try {
    const scale: number = ngfFontScaleManagerFacade.getCurrentScale();
    return scale > 0 ? scale : FALLBACK_FONT_SCALE;
  } catch (error) {
    return FALLBACK_FONT_SCALE;
  }
}

/** 当前档位 */
export function currentFontScaleLevel(): NGFFontScaleLevel {
  try {
    return ngfFontScaleManagerFacade.getCurrentLevel();
  } catch (error) {
    return NGFFontScaleLevel.NORMAL;
  }
}

/** 按档位设置（设置页的「小/标准/大/超大」） */
export function setFontScaleLevel(level: NGFFontScaleLevel): void {
  try {
    ngfFontScaleManagerFacade.setFontScaleLevel(level);
  } catch (error) {
  }
}

/** 恢复跟随系统 */
export function resetFontScaleToSystem(): void {
  try {
    ngfFontScaleManagerFacade.resetToSystem();
  } catch (error) {
  }
}

/** 订阅缩放变化 */
export function onFontScaleChanged(callback: (scale: number) => void): void {
  try {
    ngfFontScaleManagerFacade.onScaleChanged(callback);
  } catch (error) {
  }
}

export function offFontScaleChanged(callback: (scale: number) => void): void {
  try {
    ngfFontScaleManagerFacade.offScaleChanged(callback);
  } catch (error) {
  }
}

/**
 * 把一个设计稿字号换算成当前该用的字号。
 *
 * 页面统一用 \`scaled(14)\` 代替 \`14\`，关怀模式就自动生效。
 * 结果取整并保证至少 1vp——缩放到 0 会让文字彻底消失。
 */
export function scaled(size: number): number {
  const value: number = Math.round(size * currentFontScale());
  return value < 1 ? 1 : value;
}
