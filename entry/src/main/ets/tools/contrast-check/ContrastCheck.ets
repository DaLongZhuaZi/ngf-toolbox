/**
 * WCAG 对比度检查的纯逻辑实现（复用 color-convert 的标准实现）。
 *
 * ## 复用而非复制
 *
 * relativeLuminance / contrastRatio 直接 import 自 color-convert/ColorConvert——
 * 那份实现带着「先做伽马展开再算亮度」的关键注释（最常见的 WCAG 实现错误）。
 * 复制一份迟早漂移，漂移之后本工具与主题门禁会互相矛盾。
 *
 * ## WCAG 2.1 等级
 *
 * AA：普通文本 ≥ 4.5、大文本 ≥ 3.0；AAA：普通文本 ≥ 7.0、大文本 ≥ 4.5。
 * 「大文本」= 18pt（约 24px）或 14pt bold（约 18.66px）——这里让调用方传入
 * 是否大文本，工具只管按口径判定。
 *
 * @module tools/contrast-check/ContrastCheck
 */

import { contrastRatio, NGFColor, relativeLuminance } from '../color-convert/ColorConvert';

/** 失败原因码 */
export enum ContrastFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  /** 两个输入颜色相同 */
  SAME_COLOR = 'same_color'
}

/** 一次失败的原因与文案参数 */
export class ContrastFailure {
  readonly code: ContrastFailureCode;
  readonly args: Array<string>;

  constructor(code: ContrastFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** WCAG 等级 */
export enum WcagLevel {
  AAA = 'aaa',
  AA = 'aa',
  AA_LARGE = 'aa_large',
  FAIL = 'fail'
}

/** 检查结果 */
export class ContrastCheckResult {
  readonly ok: boolean;
  readonly failure: ContrastFailure;
  readonly ratio: number;
  readonly level: WcagLevel;
  /** 亮度较高的一方是黑色文字还是白色文字（可读性建议用） */
  readonly preferDarkText: boolean;

  constructor(ok: boolean, failure: ContrastFailure, ratio: number,
    level: WcagLevel, preferDarkText: boolean) {
    this.ok = ok;
    this.failure = failure;
    this.ratio = ratio;
    this.level = level;
    this.preferDarkText = preferDarkText;
  }
}

/** 按 WCAG 2.1 判等级 */
export function judgeLevel(ratio: number, isLargeText: boolean): WcagLevel {
  if (isLargeText) {
    if (ratio >= 4.5) {
      return WcagLevel.AAA;
    }
    if (ratio >= 3.0) {
      return WcagLevel.AA_LARGE;
    }
    return WcagLevel.FAIL;
  }
  if (ratio >= 7.0) {
    return WcagLevel.AAA;
  }
  if (ratio >= 4.5) {
    return WcagLevel.AA;
  }
  return WcagLevel.FAIL;
}

function parseHexColor(text: string): number[] | null {
  let t: string = text.trim();
  if (t.charAt(0) === String.fromCharCode(35)) {
    t = t.substring(1);
  }
  if (t.length !== 3 && t.length !== 6) {
    return null;
  }
  if (t.length === 3) {
    let expanded: string = '';
    for (let i = 0; i < 3; i++) {
      expanded = expanded + t.charAt(i) + t.charAt(i);
    }
    t = expanded;
  }
  const values: Array<number> = [];
  for (let i = 0; i < 6; i = i + 2) {
    const hi: number = parseInt(t.charAt(i), 16);
    const lo: number = parseInt(t.charAt(i + 1), 16);
    if (isNaN(hi) || isNaN(lo)) {
      return null;
    }
    values.push(hi * 16 + lo);
  }
  return values;
}

/** 主入口：前景色与背景色的对比度 + 等级 */
export function checkContrast(foregroundText: string, backgroundText: string,
  isLargeText: boolean): ContrastCheckResult {
  if (foregroundText.trim().length === 0 || backgroundText.trim().length === 0) {
    return new ContrastCheckResult(false,
      new ContrastFailure(ContrastFailureCode.EMPTY_INPUT, []), 0, WcagLevel.FAIL, false);
  }
  const fg: number[] | null = parseHexColor(foregroundText);
  const bg: number[] | null = parseHexColor(backgroundText);
  if (fg === null || bg === null) {
    return new ContrastCheckResult(false,
      new ContrastFailure(ContrastFailureCode.EMPTY_INPUT, [foregroundText, backgroundText]),
      0, WcagLevel.FAIL, false);
  }
  if (fg[0] === bg[0] && fg[1] === bg[1] && fg[2] === bg[2]) {
    return new ContrastCheckResult(false,
      new ContrastFailure(ContrastFailureCode.SAME_COLOR, []), 1, WcagLevel.FAIL, false);
  }
  const fgColor: NGFColor = NGFColor.of(fg[0], fg[1], fg[2]);
  const bgColor: NGFColor = NGFColor.of(bg[0], bg[1], bg[2]);
  const ratio: number = contrastRatio(fgColor, bgColor);
  const blackLum: number = relativeLuminance(NGFColor.of(0, 0, 0));
  const whiteLum: number = relativeLuminance(NGFColor.of(255, 255, 255));
  const preferDarkText: boolean =
    contrastRatio(NGFColor.of(0, 0, 0), bgColor) >=
    contrastRatio(NGFColor.of(255, 255, 255), bgColor);
  return new ContrastCheckResult(true,
    new ContrastFailure(ContrastFailureCode.NONE, []), ratio,
    judgeLevel(ratio, isLargeText), preferDarkText);
}
