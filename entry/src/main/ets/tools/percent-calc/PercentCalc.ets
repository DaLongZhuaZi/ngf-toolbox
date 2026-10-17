/**
 * 百分比计算的纯逻辑实现。
 *
 * ## 五个计算方向（都是一行的算术，但**措辞方向**容易搞混）
 *
 * 1. 占比：X 是 Y 的百分之几 = X/Y*100
 * 2. 求部分：Y 的 P% 是多少 = Y*P/100
 * 3. 增长率：从 A 到 B 变化了百分之几 = (B-A)/A*100
 * 4. 求总数：已知 P% 是 X，总数是多少 = X/(P/100)
 * 5. 加减百分比：Y 增/减 P% = Y*(1±P/100)
 *
 * 每个方向独立函数与独立失败码——调用方（页面）按用户选择的 tab 调用，
 * 不做一个大函数按参数分派（分派会让「除零在哪一步发生」变得含糊）。
 *
 * @module tools/percent-calc/PercentCalc
 */

/** 失败原因码 */
export enum PercentFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  NOT_A_NUMBER = 'not_a_number',
  /** 除数为零（占比/增长率/求总数的分母） */
  DIVIDE_BY_ZERO = 'divide_by_zero'
}

/** 一次失败的原因与文案参数 */
export class PercentFailure {
  readonly code: PercentFailureCode;
  readonly args: Array<string>;

  constructor(code: PercentFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 计算结果 */
export class PercentResult {
  readonly ok: boolean;
  readonly failure: PercentFailure;
  readonly value: number;

  constructor(ok: boolean, failure: PercentFailure, value: number) {
    this.ok = ok;
    this.failure = failure;
    this.value = value;
  }
}

function parseNumber(text: string): number {
  if (text.trim().length === 0) {
    return NaN;
  }
  const n: number = parseFloat(text);
  return isNaN(n) ? NaN : n;
}

function failIfNaN(values: Array<number>): PercentFailure | null {
  for (let i = 0; i < values.length; i++) {
    if (isNaN(values[i])) {
      return new PercentFailure(PercentFailureCode.NOT_A_NUMBER, []);
    }
  }
  return null;
}

function failIfZero(value: number): PercentFailure | null {
  if (value === 0) {
    return new PercentFailure(PercentFailureCode.DIVIDE_BY_ZERO, []);
  }
  return null;
}

/** 1. 占比：part 是 total 的百分之几 */
export function percentOf(partText: string, totalText: string): PercentResult {
  const part: number = parseNumber(partText);
  const total: number = parseNumber(totalText);
  const nanFail: PercentFailure | null = failIfNaN([part, total]);
  if (nanFail !== null) {
    return new PercentResult(false, nanFail, 0);
  }
  const zeroFail: PercentFailure | null = failIfZero(total);
  if (zeroFail !== null) {
    return new PercentResult(false, zeroFail, 0);
  }
  return new PercentResult(true, new PercentFailure(PercentFailureCode.NONE, []), part / total * 100);
}

/** 2. 求部分：total 的 percent% 是多少 */
export function partOfTotal(totalText: string, percentText: string): PercentResult {
  const total: number = parseNumber(totalText);
  const percent: number = parseNumber(percentText);
  const nanFail: PercentFailure | null = failIfNaN([total, percent]);
  if (nanFail !== null) {
    return new PercentResult(false, nanFail, 0);
  }
  return new PercentResult(true, new PercentFailure(PercentFailureCode.NONE, []), total * percent / 100);
}

/** 3. 增长率：from 到 to 变化了百分之几（可负） */
export function changeRate(fromText: string, toText: string): PercentResult {
  const from: number = parseNumber(fromText);
  const to: number = parseNumber(toText);
  const nanFail: PercentFailure | null = failIfNaN([from, to]);
  if (nanFail !== null) {
    return new PercentResult(false, nanFail, 0);
  }
  const zeroFail: PercentFailure | null = failIfZero(from);
  if (zeroFail !== null) {
    return new PercentResult(false, zeroFail, 0);
  }
  return new PercentResult(true, new PercentFailure(PercentFailureCode.NONE, []), (to - from) / from * 100);
}

/** 4. 求总数：percent% 是 part，总数是多少 */
export function totalFromPart(partText: string, percentText: string): PercentResult {
  const part: number = parseNumber(partText);
  const percent: number = parseNumber(percentText);
  const nanFail: PercentFailure | null = failIfNaN([part, percent]);
  if (nanFail !== null) {
    return new PercentResult(false, nanFail, 0);
  }
  const zeroFail: PercentFailure | null = failIfZero(percent);
  if (zeroFail !== null) {
    return new PercentResult(false, zeroFail, 0);
  }
  return new PercentResult(true, new PercentFailure(PercentFailureCode.NONE, []), part / (percent / 100));
}

/** 5. 加减百分比：base 增（positive）或减 P% */
export function applyPercent(baseText: string, percentText: string, positive: boolean): PercentResult {
  const base: number = parseNumber(baseText);
  const percent: number = parseNumber(percentText);
  const nanFail: PercentFailure | null = failIfNaN([base, percent]);
  if (nanFail !== null) {
    return new PercentResult(false, nanFail, 0);
  }
  const factor: number = positive ? 1 + percent / 100 : 1 - percent / 100;
  return new PercentResult(true, new PercentFailure(PercentFailureCode.NONE, []), base * factor);
}
