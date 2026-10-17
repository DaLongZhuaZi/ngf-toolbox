/**
 * 无障碍（Accessibility）的**唯一出口**（UI 层）。
 *
 * ## 为什么这件事必须从底层做
 *
 * 首版开发时整个 app **没有任何** accessibilityText / accessibilityDescription /
 * accessibilityLevel / accessibilityGroup，也没调用过框架的无障碍门面——
 * 也就是说读屏用户点进来会听到一堆没有名字的控件。
 * 这不是「少加几个属性」，而是没把无障碍当成底层能力。
 *
 * ## 框架侧的一个缺口（本仓已先行修补）
 *
 * \`AccessibilityFacade\` 文件一直存在，但 \`deviceAwareness/index.ets\` 漏了导出，
 * 导致顶层拿不到。本仓已按 AGENTS.md §4 先行补上并追记 \`ngf_framework/VENDORED.md\`，
 * **需回来源仓同步**。
 *
 * ## 页面该怎么用
 *
 * 1. 纯展示文本：交给读屏读文本本身，但**图标按钮必须给标签**；
 * 2. 图标按钮：\`.accessibilityText(a11yLabel('tool.xxx.copy', '复制'))\`；
 * 3. 成组控件（一张卡片里的多条信息）：加 \`.accessibilityGroup(true)\` 让读屏一次读完，
 *    不要一条条念；
 * 4. 装饰性元素（分隔线、背景块）：\`.accessibilityLevel('no')\` 让读屏跳过。
 *
 * @module ui/A11y
 */

import { ngfAccessibilityFacade } from 'ngf_framework';

/** 无障碍是否可用；读取失败一律按「不可用」处理，不抛异常 */
export function accessibilityEnabled(): boolean {
  try {
    return ngfAccessibilityFacade.isAccessibilityEnabled();
  } catch (error) {
    return false;
  }
}

/**
 * 读屏是否开启。
 *
 * 用途不只是「给不给标签」——读屏开启时应当**降低动效、加长提示停留时间**，
 * 因为用户要靠听来理解界面变化，一闪而过的动画只会干扰。
 */
export function screenReaderEnabled(): boolean {
  try {
    return ngfAccessibilityFacade.isScreenReaderEnabled();
  } catch (error) {
    return false;
  }
}

/**
 * 组装无障碍标签。
 *
 * @param componentId 稳定的组件标识（建议 \`<toolId>.<部位>\`，例如 \`digest.result.copy\`）。
 *                    **不要用界面文案当标识**：文案是会翻译的，标识不该跟着变。
 * @param label 读屏念出来的文案
 */
export function a11yLabel(componentId: string, label: string): string {
  try {
    const built: string = ngfAccessibilityFacade.buildAccessibilityLabel(componentId, label);
    return built.length > 0 ? built : label;
  } catch (error) {
    return label;
  }
}

/** 组装操作提示（读屏会念「双击以…」这类） */
export function a11yHint(action: string): string {
  try {
    const built: string = ngfAccessibilityFacade.buildAccessibilityHint(action);
    return built.length > 0 ? built : action;
  } catch (error) {
    return action;
  }
}

/** 装饰性元素的等级：让读屏直接跳过 */
export const A11Y_LEVEL_NO: string = 'no';
/** 重要元素的等级：读屏会优先/必然读到 */
export const A11Y_LEVEL_YES: string = 'yes';
/** 自动（默认） */
export const A11Y_LEVEL_AUTO: string = 'auto';
