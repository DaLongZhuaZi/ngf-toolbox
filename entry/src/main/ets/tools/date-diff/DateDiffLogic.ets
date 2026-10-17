/**
 * 日期差计算的纯逻辑实现。
 *
 * ## 功能
 *
 * 两个 ISO 日期之间：自然日差（含方向）、工作日数（跳过周末）、周数。
 * 使用 UTC 日期算术。start 晚于 end 时结果为负。
 *
 * @module tools/date-diff/DateDiffLogic
 */

/** 失败原因码 */
export enum DateDiffFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  BAD_DATE = 'bad_date'
}

/** 一次失败的原因与文案参数 */
export class DateDiffFailure {
  readonly code: DateDiffFailureCode;
  readonly args: Array<string>;

  constructor(code: DateDiffFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 结果 */
export class DateDiffResult {
  readonly ok: boolean;
  readonly failure: DateDiffFailure;
  readonly naturalDays: number;
  readonly workdays: number;
  readonly weeks: number;

  constructor(ok: boolean, failure: DateDiffFailure, naturalDays: number,
    workdays: number, weeks: number) {
    this.ok = ok;
    this.failure = failure;
    this.naturalDays = naturalDays;
    this.workdays = workdays;
    this.weeks = weeks;
  }
}
/** ISO 解析：YYYY-MM-DD 转 UTC 毫秒；非法返回 NaN */
export function parseIsoDate(text: string): number {
  const t: string = text.trim();
  if (t.length !== 10 || t.charAt(4) !== '-' || t.charAt(7) !== '-') {
    return NaN;
  }
  const y: number = parseInt(t.substring(0, 4), 10);
  const mo: number = parseInt(t.substring(5, 7), 10);
  const d: number = parseInt(t.substring(8, 10), 10);
  if (isNaN(y) || isNaN(mo) || isNaN(d)) {
    return NaN;
  }
  if (mo < 1 || mo > 12 || d < 1 || d > 31) {
    return NaN;
  }
  return Date.UTC(y, mo - 1, d);
}
/** 主入口 */
export function diffDates(startText: string, endText: string): DateDiffResult {
  if (startText.trim().length === 0 || endText.trim().length === 0) {
    return new DateDiffResult(false, new DateDiffFailure(DateDiffFailureCode.EMPTY_INPUT, []), 0, 0, 0);
  }
  const startMs: number = parseIsoDate(startText);
  const endMs: number = parseIsoDate(endText);
  if (isNaN(startMs) || isNaN(endMs)) {
    return new DateDiffResult(false, new DateDiffFailure(DateDiffFailureCode.BAD_DATE, []), 0, 0, 0);
  }
  const DAY: number = 86400000;
  const diffDays: number = Math.round((endMs - startMs) / DAY);
  const step: number = diffDays >= 0 ? 1 : -1;
  let remaining: number = Math.abs(diffDays);
  let workdays: number = 0;
  let cursor: number = startMs;
  while (remaining > 0) {
    cursor = cursor + step * DAY;
    const wd: number = new Date(cursor).getUTCDay();
    if (wd !== 0 && wd !== 6) {
      workdays = workdays + step;
    }
    remaining = remaining - 1;
  }
  const weeks: number = Math.trunc(diffDays / 7);
  return new DateDiffResult(true, new DateDiffFailure(DateDiffFailureCode.NONE, []),
    diffDays, workdays, weeks);
}