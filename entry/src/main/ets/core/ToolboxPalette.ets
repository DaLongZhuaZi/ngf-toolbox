/**
 * 工具箱的调色板（**纯数据**，零设备依赖）。
 *
 * ## 为什么单独成一个模块
 *
 * 这份色表有两个消费者，而且它们必须在**同一份数据**上工作：
 * 1. `ui/ThemeSource.ets` —— 启动时把色值注册进框架的 Token 体系；
 * 2. `tools/verify/check-theme-contrast.mjs` —— 审计明暗两套色的对比度。
 *
 * 如果色值只写在 ThemeSource 里，门禁就只能靠正则去啃源码；如果两边各写一份，
 * 迟早漂移——而漂移之后**门禁会开始骗人**：它审的是一份早已不用的色表。
 * 所以数据放这里，两边都 import 它。
 *
 * ## 为什么是纯数据
 *
 * 本文件不 import ArkUI（只 import `NGFColorToken`/`NGFColorValue` 这两个纯符号），
 * 因此能在 Node 里被直接加载。这是它可被审计的前提。
 * `tools/verify/ngf-stub.mjs` 提供了同名同值的枚举桩。
 *
 * ## 色值的来源
 *
 * 首版自建的两份 `resources/base|dark/element/color.json`（14 个键）一一对应迁移过来，
 * 迁移期间两套并存也不会出现颜色不一致。多出来的 5 个语义 Token
 * （error_container 起）见 `ngf_framework/VENDORED.md`。
 *
 * @module core/ToolboxPalette
 */

import { NGFColorToken, NGFColorValue } from 'ngf_framework';

/**
 * 全部 25 个语义 Token 的明/暗色值。
 *
 * 顺序按 Token 枚举排列，方便与 `IColorTokenProvider.ets` 对照检查漏项。
 */
export function toolboxPalette(): Array<NGFColorValue> {
  const list: Array<NGFColorValue> = [];
  list.push(new NGFColorValue(NGFColorToken.PRIMARY, '#0962F2', '#5B9CFF'));
  list.push(new NGFColorValue(NGFColorToken.ON_PRIMARY, '#FFFFFF', '#101418'));
  list.push(new NGFColorValue(NGFColorToken.PRIMARY_CONTAINER, '#E8F0FE', '#16243A'));
  list.push(new NGFColorValue(NGFColorToken.ON_PRIMARY_CONTAINER, '#0962F2', '#5B9CFF'));
  list.push(new NGFColorValue(NGFColorToken.SECONDARY, '#636E7E', '#9AA4B2'));
  list.push(new NGFColorValue(NGFColorToken.ON_SECONDARY, '#FFFFFF', '#101418'));
  list.push(new NGFColorValue(NGFColorToken.SECONDARY_CONTAINER, '#F7F8FA', '#151A20'));
  list.push(new NGFColorValue(NGFColorToken.ON_SECONDARY_CONTAINER, '#182431', '#E8EAED'));
  list.push(new NGFColorValue(NGFColorToken.TERTIARY, '#1D8147', '#5FD08A'));
  list.push(new NGFColorValue(NGFColorToken.ON_TERTIARY, '#FFFFFF', '#101418'));
  list.push(new NGFColorValue(NGFColorToken.SURFACE, '#FFFFFF', '#1A1F26'));
  list.push(new NGFColorValue(NGFColorToken.ON_SURFACE, '#182431', '#E8EAED'));
  list.push(new NGFColorValue(NGFColorToken.SURFACE_VARIANT, '#F7F8FA', '#151A20'));
  list.push(new NGFColorValue(NGFColorToken.ON_SURFACE_VARIANT, '#636E7E', '#9AA4B2'));
  list.push(new NGFColorValue(NGFColorToken.BACKGROUND, '#F1F3F5', '#101418'));
  list.push(new NGFColorValue(NGFColorToken.ON_BACKGROUND, '#182431', '#E8EAED'));
  list.push(new NGFColorValue(NGFColorToken.ERROR_COLOR, '#C93726', '#FF7B6B'));
  list.push(new NGFColorValue(NGFColorToken.ON_ERROR, '#FFFFFF', '#101418'));
  list.push(new NGFColorValue(NGFColorToken.OUTLINE, '#636E7E', '#9AA4B2'));
  list.push(new NGFColorValue(NGFColorToken.OUTLINE_VARIANT, '#E4E7EB', '#2A313A'));
  list.push(new NGFColorValue(NGFColorToken.ERROR_CONTAINER, '#FDEDEC', '#2E1B18'));
  list.push(new NGFColorValue(NGFColorToken.ON_ERROR_CONTAINER, '#C93726', '#FF7B6B'));
  list.push(new NGFColorValue(NGFColorToken.WARNING, '#A45E0A', '#F0B457'));
  list.push(new NGFColorValue(NGFColorToken.WARNING_CONTAINER, '#FDF3E3', '#2B2417'));
  list.push(new NGFColorValue(NGFColorToken.SUCCESS, '#1D8147', '#5FD08A'));
  return list;
}
