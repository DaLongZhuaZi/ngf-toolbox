/**
 * 颜色转换的显示文案（**UI 层**，可以 import ArkUI）。
 *
 * ## 分工
 *
 * `ColorConvert.ets` 是纯逻辑，不能 import ArkUI 的 `$r()`，所以它只给：
 * - 解析失败是哪种（`ColorParseFailure`）+ 文案参数；
 * - 数值结果（`NGFColorReport`）；
 * - 双语数据（`NGFHarmonyOption.label`）。
 *
 * 「怎么说」全在这里。`formatColorText` 原先住在纯逻辑层，它产出的每一行都是
 * 「标签：值」——标签是文案，所以搬了过来；而 HEX / RGB / HSL / HSV / CMYK
 * 这些是**缩写**、两种语言写法一样，继续留在 `NGFColorReport` 里。
 *
 * @module tools/color-convert/ColorConvertMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import {
  ColorParseFailure,
  NGFColor,
  NGFColorReport,
  NGFContrastVerdict,
  NGFHarmonyOption,
  toHex
} from './ColorConvert';

/** 解析失败翻译成人话 */
export function colorParseFailureText(failure: ColorParseFailure,
  args: Array<string>): string {
  if (failure === ColorParseFailure.EMPTY) {
    return ToolUiKit.text($r('app.string.color_err_empty'));
  }
  if (failure === ColorParseFailure.UNKNOWN_FORMAT) {
    return ToolUiKit.text($r('app.string.color_err_unknown_format'));
  }
  if (failure === ColorParseFailure.HEX_BAD_CHAR) {
    return ToolUiKit.text($r('app.string.color_err_hex_bad_char'));
  }
  if (failure === ColorParseFailure.RGB_MISSING_PAREN) {
    return ToolUiKit.text($r('app.string.color_err_rgb_missing_paren'));
  }
  if (failure === ColorParseFailure.RGB_ARITY) {
    return ToolUiKit.text($r('app.string.color_err_rgb_arity'));
  }
  if (failure === ColorParseFailure.CHANNEL_RANGE) {
    return ToolUiKit.stringOf($r('app.string.color_err_channel_range'), [args[0], args[1]]);
  }
  if (failure === ColorParseFailure.HSL_MISSING_PAREN) {
    return ToolUiKit.text($r('app.string.color_err_hsl_missing_paren'));
  }
  if (failure === ColorParseFailure.HSL_ARITY) {
    return ToolUiKit.text($r('app.string.color_err_hsl_arity'));
  }
  if (failure === ColorParseFailure.BAD_HUE) {
    return ToolUiKit.text($r('app.string.color_err_bad_hue'));
  }
  if (failure === ColorParseFailure.HSL_PERCENT) {
    return ToolUiKit.text($r('app.string.color_err_hsl_percent'));
  }
  if (failure === ColorParseFailure.UNKNOWN_NAME) {
    return ToolUiKit.text($r('app.string.color_err_unknown_name'));
  }
  return '';
}

/**
 * 颜色信息的可复制文本。
 *
 * HEX / RGB / HSL / HSV / CMYK 这些标签直接用缩写：它们是国际通用写法，
 * 两种语言下都一样，翻译它们反而会让人认不出。真正需要翻译的是
 * 「最接近的颜色名」「建议前景色」这类**说明性**标签。
 */
export function formatColorText(report: NGFColorReport): string {
  const colon: string = ToolUiKit.text($r('app.string.color_field_separator'));
  let text: string = '';
  text += 'HEX' + colon + report.hex + '\n';
  if (report.shortHex !== report.hex) {
    text += ToolUiKit.text($r('app.string.color_field_short_hex')) + colon + report.shortHex + '\n';
  }
  text += 'RGB' + colon + report.rgbText + '\n';
  text += 'HSL' + colon + report.hslText + '\n';
  text += 'HSV' + colon + report.hsvText + '\n';
  text += 'CMYK' + colon + report.cmykText + '\n';
  text += ToolUiKit.text($r('app.string.color_field_nearest_name')) + colon + report.nearestName + '\n';
  text += ToolUiKit.text($r('app.string.color_field_readable')) + colon + report.readableText + '\n';
  text += ToolUiKit.text($r('app.string.color_field_on_white')) + colon
    + String(report.contrastOnWhite) + '\n';
  text += ToolUiKit.text($r('app.string.color_field_on_black')) + colon
    + String(report.contrastOnBlack) + '\n';
  return text;
}

/**
 * 对比度结论（WCAG 档位）。
 *
 * 判据用的是 `NGFContrastVerdict` 上的三个布尔量（纯逻辑算好的），
 * 这里只决定「说哪句话」——判断归纯逻辑、措辞归 UI，与 text-diff 的分法一致。
 */
export function contrastVerdictText(verdict: NGFContrastVerdict): string {
  if (verdict.passesNormalAAA) {
    return ToolUiKit.text($r('app.string.color_verdict_aaa'));
  }
  if (verdict.passesNormalAA) {
    return ToolUiKit.text($r('app.string.color_verdict_aa'));
  }
  if (verdict.passesLargeAA) {
    return ToolUiKit.text($r('app.string.color_verdict_large_only'));
  }
  return ToolUiKit.text($r('app.string.color_verdict_fail'));
}

/** 解析结果里的附注（夹紧、含透明度） */
export function colorNoticeTexts(color: NGFColor, shorthand: boolean): Array<string> {
  const notices: Array<string> = [];
  if (color.clamped) {
    notices.push(ToolUiKit.text($r('app.string.color_notice_clamped')));
  }
  if (color.alpha < 1) {
    notices.push(ToolUiKit.stringOf($r('app.string.color_notice_alpha'),
      [String(color.alpha)]));
  }
  return notices;
}

/** 配色方案名（双语数据按 locale 取） */
export function harmonyLabel(option: NGFHarmonyOption, locale: string): string {
  return option.label.forLocale(locale);
}

/** 明暗调整按钮的文案（「亮 15%」/「暗 15%」） */
export function lightnessStepText(step: number): string {
  const percent: number = Math.round(Math.abs(step) * 100);
  return step > 0
    ? ToolUiKit.stringOf($r('app.string.color_step_lighten'), [String(percent)])
    : ToolUiKit.stringOf($r('app.string.color_step_darken'), [String(percent)]);
}

/** 复制色值的提示（「已复制 #0962F2」） */
export function copiedColorText(hex: string): string {
  return ToolUiKit.stringOf($r('app.string.color_copied_value'), [hex]);
}

/** 供页面拼「已复制 标签」用 */
export function copiedLabelText(label: string): string {
  return ToolUiKit.stringOf($r('app.string.color_copied_label'), [label]);
}

/** 色值小写化以便展示（页面用它当 key） */
export function hexOf(color: NGFColor): string {
  return toHex(color);
}
