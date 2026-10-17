/**
 * 两色混合的纯逻辑实现（RGB 线性插值）。
 *
 * ## 功能
 *
 * 输入两色 + 混合比例（0=全 A，100=全 B）得中间色；可选 N 步渐变色带。
 * 颜色解析复用 ColorConvert（同一套入口）。
 *
 * @module tools/color-blend/ColorBlendLogic
 */

import { ColorParseResult, NGFColor, parseColor, toHex } from '../color-convert/ColorConvert';

/** 失败原因码 */
export enum BlendFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  BAD_COLOR = 'bad_color'
}

/** 一次失败的原因与文案参数 */
export class BlendFailure {
  readonly code: BlendFailureCode;
  readonly args: Array<string>;

  constructor(code: BlendFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}
/** 单个渐变色 */
export class BlendSwatch {
  readonly hex: string;
  /** 该色的 B 占比（0-100） */
  readonly ratio: number;

  constructor(hex: string, ratio: number) {
    this.hex = hex;
    this.ratio = ratio;
  }
}

/** 结果 */
export class BlendResult {
  readonly ok: boolean;
  readonly failure: BlendFailure;
  readonly swatches: Array<BlendSwatch>;

  constructor(ok: boolean, failure: BlendFailure, swatches: Array<BlendSwatch>) {
    this.ok = ok;
    this.failure = failure;
    this.swatches = swatches;
  }
}

function channelAt(ca: number, cb: number, t: number): number {
  return Math.round(ca + (cb - ca) * t);
}
/** 主入口：steps 为渐变步数（2-12，含两端）；ratioB 为中点色的 B 占比 */
export function blendColors(aText: string, bText: string, steps: number): BlendResult {
  if (aText.trim().length === 0 || bText.trim().length === 0) {
    return new BlendResult(false, new BlendFailure(BlendFailureCode.EMPTY_INPUT, []), []);
  }
  const pa: ColorParseResult = parseColor(aText);
  const pb: ColorParseResult = parseColor(bText);
  if (!pa.ok || pa.color === null || !pb.ok || pb.color === null) {
    return new BlendResult(false, new BlendFailure(BlendFailureCode.BAD_COLOR, []), []);
  }
  const a: NGFColor = pa.color;
  const b: NGFColor = pb.color;
  const count: number = Math.min(12, Math.max(2, steps));
  const swatches: Array<BlendSwatch> = [];
  for (let i = 0; i < count; i++) {
    const t: number = i / (count - 1);
    const mixed: NGFColor = new NGFColor(
      channelAt(a.red, b.red, t),
      channelAt(a.green, b.green, t),
      channelAt(a.blue, b.blue, t),
      channelAt(a.alpha, b.alpha, t), false);
    swatches.push(new BlendSwatch(toHex(mixed), Math.round(t * 100)));
  }
  return new BlendResult(true, new BlendFailure(BlendFailureCode.NONE, []), swatches);
}