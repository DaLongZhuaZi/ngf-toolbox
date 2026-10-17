/**
 * 色相微调的纯逻辑实现（薄封装 ColorConvert 的 rotateHue/adjustLightness/toHsl）。
 *
 * ## 功能
 *
 * 输入色 + 色相偏移角度 + 明度偏移 → 结果色（hex 与 HSL 报告）。
 * 设计场景：主色定了之后做同色系变体（品牌色 ±15° 微调）。
 *
 * @module tools/hue-shift/HueShiftLogic
 */

import {
  adjustLightness,
  NGFColor,
  parseColor,
  rotateHue,
  toHex,
  toHsl
} from '../color-convert/ColorConvert';

/** 失败原因码 */
export enum HueShiftFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  BAD_COLOR = 'bad_color'
}

/** 一次失败的原因与文案参数 */
export class HueShiftFailure {
  readonly code: HueShiftFailureCode;
  readonly args: Array<string>;

  constructor(code: HueShiftFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 结果 */
export class HueShiftResult {
  readonly ok: boolean;
  readonly failure: HueShiftFailure;
  readonly hex: string;
  readonly hue: number;
  readonly saturation: number;
  readonly lightness: number;

  constructor(ok: boolean, failure: HueShiftFailure, hex: string,
    hue: number, saturation: number, lightness: number) {
    this.ok = ok;
    this.failure = failure;
    this.hex = hex;
    this.hue = hue;
    this.saturation = saturation;
    this.lightness = lightness;
  }
}

/** 主入口：色相偏移 + 明度偏移（-100~100 视作 HSL 百分比偏移） */
export function shiftHue(colorText: string, hueDegrees: number,
  lightnessShift: number): HueShiftResult {
  if (colorText.trim().length === 0) {
    return new HueShiftResult(false, new HueShiftFailure(HueShiftFailureCode.EMPTY_INPUT, []), '', 0, 0, 0);
  }
  const parsed = parseColor(colorText);
  if (!parsed.ok) {
    return new HueShiftResult(false, new HueShiftFailure(HueShiftFailureCode.BAD_COLOR, [colorText]), '', 0, 0, 0);
  }
  let color: NGFColor = parsed.color as NGFColor;
  if (hueDegrees !== 0) {
    color = rotateHue(color, hueDegrees);
  }
  if (lightnessShift !== 0) {
    color = adjustLightness(color, lightnessShift);
  }
  const hsl = toHsl(color);
  return new HueShiftResult(true, new HueShiftFailure(HueShiftFailureCode.NONE, []),
    toHex(color), hsl.hue, hsl.saturation, hsl.lightness);
}