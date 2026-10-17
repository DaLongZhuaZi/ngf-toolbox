/**
 * 里程碑/迭代计算的纯逻辑实现（工作日加减，周末跳过）。
 *
 * ## 规则
 *
 * 输入 ISO 日期（YYYY-MM-DD）与工作日数（可负）：按日推进、周六周日跳过。
 * 输出结果日期与经过的自然日数。使用 UTC 日期算术（避免时区偏移问题）。
 *
 * @module tools/sprint-calc/SprintLogic
 */

/** 失败原因码 */
export enum SprintFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  BAD_DATE = 'bad_date',
  DAYS_TOO_LARGE = 'days_too_large'
}

/** 一次失败的原因与文案参数 */
export class SprintFailure {
  readonly code: SprintFailureCode;
  readonly args: Array<string>;

  constructor(code: SprintFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 结果 */
export class SprintResult {
  readonly ok: boolean;
  readonly failure: SprintFailure;
  /** 结果日期（ISO） */
  readonly resultDate: string;
  /** 结果日是星期几：0=周日 1=周一 ... 6=周六 */
  readonly resultWeekday: number;
  /** 消耗的自然日数（绝对值） */
  readonly naturalDays: number;

  constructor(ok: boolean, failure: SprintFailure, resultDate: string,
    resultWeekday: number, naturalDays: number) {
    this.ok = ok;
    this.failure = failure;
    this.resultDate = resultDate;
    this.resultWeekday = resultWeekday;
    this.naturalDays = naturalDays;
  }
}

const MAX_DAYS: number = 3650;

/** ISO 解析：YYYY-MM-DD → UTC 毫秒；非法返回 NaN */
function parseIsoDate(text: string): number {
  const t: string = text.trim();
  if (t.length !== 10 || t.charAt(4) !== '-' || t.charAt(7) !== '-') {
    return NaN;
  }
  const y: number = parseInt(t.substring(0, 4), 10);
  const m: number = parseInt(t.substring(5, 7), 10);
  const d: number = parseInt(t.substring(8, 10), 10);
  if (isNaN(y) || isNaN(m) || isNaN(d)) {
    return NaN;
  }
  if (m < 1 || m > 12 || d < 1 || d > 31) {
    return NaN;
  }
  return Date.UTC(y, m - 1, d);
}

function toIso(ms: number): string {
  const d: Date = new Date(ms);
  const y: string = String(d.getUTCFullYear());
  let m: string = String(d.getUTCMonth() + 1);
  let day: string = String(d.getUTCDate());
  if (m.length === 1) {
    m = '0' + m;
  }
  if (day.length === 1) {
    day = '0' + day;
  }
  return y + '-' + m + '-' + day;
}

/** 主入口 */
export function addWorkdays(dateText: string, daysText: string): SprintResult {
  if (dateText.trim().length === 0 || daysText.trim().length === 0) {
    return new SprintResult(false, new SprintFailure(SprintFailureCode.EMPTY_INPUT, []), '', 0, 0);
  }
  const startMs: number = parseIsoDate(dateText);
  if (isNaN(startMs)) {
    return new SprintResult(false, new SprintFailure(SprintFailureCode.BAD_DATE, []), '', 0, 0);
  }
  const days: number = parseInt(daysText, 10);
  if (isNaN(days) || days === 0 || Math.abs(days) > MAX_DAYS) {
    return new SprintResult(false, new SprintFailure(SprintFailureCode.DAYS_TOO_LARGE, []), '', 0, 0);
  }
  const step: number = days > 0 ? 1 : -1;
  let remaining: number = Math.abs(days);
  let cursor: number = startMs;
  let natural: number = 0;
  while (remaining > 0) {
    cursor = cursor + step * 86400000;
    natural++;
    const weekday: number = new Date(cursor).getUTCDay();
    if (weekday !== 0 && weekday !== 6) {
      remaining--;
    }
  }
  const resultDate: string = toIso(cursor);
  const weekday: number = new Date(cursor).getUTCDay();
  return new SprintResult(true, new SprintFailure(SprintFailureCode.NONE, []),
    resultDate, weekday, natural);
}