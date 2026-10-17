/**
 * 5 段标准 cron 表达式的解析、求值与描述（纯逻辑）。
 *
 * ## 支持的范围（诚实边界写在页面 limitation 里）
 *
 * - **只支持标准 5 段**：分 时 日 月 周。秒级（6 段）、`@daily` 这类别名、
 *   Quartz 的 `?`/`L`/`W` 一律不支持——它们的语义在不同调度器里并不一致，
 *   假装支持只会给出错的执行时间。
 * - 支持 `*`、`,`、`-`、`/`，以及英文月份（JAN-DEC）与星期（SUN-SAT）缩写。
 *
 * ## 必须处理对的那个经典坑：日与周的「或」
 *
 * Vixie cron 的规则是：**当日与周都不是 `*` 时，两者是「或」关系**——
 * `0 0 1 * 1` 表示「每月 1 号**或**每周一」，而不是「每月 1 号且是周一」。
 * 这条规则反直觉，几乎每个手写实现都会先写错一次，所以：
 * - 判断逻辑单独抽成 {@link cronDayMatches} 并直接单测；
 * - 描述文案在命中该情况时显式写「或」，见 {@link CronParseResult.dayRuleNote}。
 *
 * @module tools/cron-parser/CronParser
 */

/** 单个字段的解析结果 */
export class CronField {
  /** 段标识（段名是文案，按它由 UI 层补） */
  readonly fieldKey: CronFieldKey;
  /** 原文（描述文案要用它区分「* / 5」与「0,5,10」这类写法） */
  readonly raw: string;
  /** 展开后的取值，升序去重 */
  readonly values: number[];
  /** 原文就是 \*（日/周判断"或"关系时要看这个，不能看 values 是否覆盖全集） */
  readonly isWildcard: boolean;
  /** 步长（A/N 或 A-B/N 里的 N）；没有步长时为 0 */
  readonly step: number;

  constructor(fieldKey: CronFieldKey, raw: string, values: number[], isWildcard: boolean,
    step: number) {
    this.fieldKey = fieldKey;
    this.raw = raw;
    this.values = values;
    this.isWildcard = isWildcard;
    this.step = step;
  }

  /** 取值里是否包含某个数 */
  contains(value: number): boolean {
    for (let i: number = 0; i < this.values.length; i++) {
      if (this.values[i] === value) {
        return true;
      }
    }
    return false;
  }
}

/** 顶层失败的原因码（段内的具体原因另见 CronFieldError） */
export enum CronParseFailureCode {
  NONE = 'none',
  /** 表达式为空 */
  EMPTY = 'empty',
  /** 段数不是 5 */
  WRONG_SEGMENT_COUNT = 'wrong_segment_count',
  /** 附注：6 段（含秒）写法不被支持 */
  SIX_SEGMENTS = 'six_segments',
  /** 附注：@daily 这类别名不被支持 */
  ALIAS = 'alias',
  /** 某一解析失败（细节在 fieldCode / fieldKey / fieldArgs） */
  FIELD = 'field'
}

/**
 * 顶层失败：主原因 + 若干附注 + 可选的段内细节。
 *
 * 为什么是「一串码」而不是一个码：段数不对时页面要说三句话
 * （基础说明、6 段说明、别名说明），哪几句说取决于输入。
 * 把它们都列出来，UI 层逐句翻译再拼——**每句各自是完整句子**，
 * 所以拼接在这里是安全的（把词嵌进句子中间才是 i18n 的坑）。
 */
export class CronParseFailure {
  /** 第一项是主原因，其余是附注 */
  readonly codes: Array<CronParseFailureCode>;
  readonly args: Array<string>;
  /** 段内失败的原因（code 为 FIELD 时有效） */
  readonly fieldCode: CronFieldError;
  readonly fieldKey: CronFieldKey;
  readonly fieldArgs: Array<string>;

  constructor(codes: Array<CronParseFailureCode>, args: Array<string>,
    fieldCode: CronFieldError, fieldKey: CronFieldKey, fieldArgs: Array<string>) {
    this.codes = codes;
    this.args = args;
    this.fieldCode = fieldCode;
    this.fieldKey = fieldKey;
    this.fieldArgs = fieldArgs;
  }

  static none(): CronParseFailure {
    return new CronParseFailure([], [], CronFieldError.NONE, CronFieldKey.MINUTE, []);
  }

  static of(code: CronParseFailureCode, args: Array<string>): CronParseFailure {
    return new CronParseFailure([code], args, CronFieldError.NONE, CronFieldKey.MINUTE, []);
  }

  /** 段内失败：把出错段下标交给字段，具体原因一并带上 */
  static ofField(error: CronFieldError, key: CronFieldKey,
    args: Array<string>): CronParseFailure {
    return new CronParseFailure([CronParseFailureCode.FIELD], [], error, key, args);
  }
}

/**
 * 人话描述的**结构**。
 *
 * 原先 buildDescription 直接拼中文句子（'每 5 分钟（9、17 点内）'）。
 * 英文不是逐词替换：同样一句是 "Every 5 minutes (during hours 9 and 17)"——
 * 量词、连接词、括号位置全不同。所以这里只给「按哪种基准 + 哪些数字」，
 * 怎么摆是每种语言自己的事。
 */
export enum CronTimeBasis {
  NONE = 'none',
  /** 每分钟 */
  EVERY_MINUTE = 'every_minute',
  /** 每 N 分钟 */
  EVERY_N_MINUTES = 'every_n_minutes',
  /** 每小时的第 M 分 */
  AT_MINUTE_OF_EVERY_HOUR = 'at_minute_of_every_hour',
  /** 每天固定时刻 */
  AT_TIMES = 'at_times'
}

export class CronDescription {
  readonly basis: CronTimeBasis;
  readonly step: number;
  readonly minutes: Array<number>;
  readonly hours: Array<number>;
  /** hours 是否为 *（EVERY_N_MINUTES 的「（…点内）」只在它非 * 时出现） */
  readonly hoursRestricted: boolean;
  readonly months: Array<number>;
  readonly daysOfMonth: Array<number>;
  readonly daysOfWeek: Array<number>;
  readonly monthsRestricted: boolean;
  readonly daysOfMonthRestricted: boolean;
  readonly daysOfWeekRestricted: boolean;
  /** 日与周都限定时两者是「或」关系（文案里要用「或」而不是「且」） */
  readonly dayFieldsAreOr: boolean;

  constructor(basis: CronTimeBasis, step: number, minutes: Array<number>, hours: Array<number>,
    hoursRestricted: boolean, months: Array<number>, daysOfMonth: Array<number>,
    daysOfWeek: Array<number>, monthsRestricted: boolean, daysOfMonthRestricted: boolean,
    daysOfWeekRestricted: boolean, dayFieldsAreOr: boolean) {
    this.basis = basis;
    this.step = step;
    this.minutes = minutes;
    this.hours = hours;
    this.hoursRestricted = hoursRestricted;
    this.months = months;
    this.daysOfMonth = daysOfMonth;
    this.daysOfWeek = daysOfWeek;
    this.monthsRestricted = monthsRestricted;
    this.daysOfMonthRestricted = daysOfMonthRestricted;
    this.daysOfWeekRestricted = daysOfWeekRestricted;
    this.dayFieldsAreOr = dayFieldsAreOr;
  }

  static none(): CronDescription {
    return new CronDescription(CronTimeBasis.NONE, 0, [], [], false, [], [], [], false, false,
      false, false);
  }
}

/** 解析结果 */
export class CronParseResult {
  readonly ok: boolean;
  /** 失败原因；成功时为 {@link CronParseFailure.none}（**永不为 null**） */
  readonly failure: CronParseFailure;
  /** 出错段下标（0-4），-1 表示没有出错 */
  readonly segmentIndex: number;
  readonly minutes: CronField | null;
  readonly hours: CronField | null;
  readonly daysOfMonth: CronField | null;
  readonly months: CronField | null;
  readonly daysOfWeek: CronField | null;
  /** 人话描述的结构（措辞在 UI 层）；解析失败时为 NONE */
  readonly description: CronDescription;
  /** 「日」与「星期」同时限定时是「或」关系（页面据此加一句提示） */
  readonly hasOrRule: boolean;

  constructor(ok: boolean, failure: CronParseFailure, segmentIndex: number,
    minutes: CronField | null, hours: CronField | null, daysOfMonth: CronField | null,
    months: CronField | null, daysOfWeek: CronField | null, description: CronDescription,
    hasOrRule: boolean) {
    this.ok = ok;
    this.failure = failure;
    this.segmentIndex = segmentIndex;
    this.minutes = minutes;
    this.hours = hours;
    this.daysOfMonth = daysOfMonth;
    this.months = months;
    this.daysOfWeek = daysOfWeek;
    this.description = description;
    this.hasOrRule = hasOrRule;
  }

  static failure(failure: CronParseFailure, segmentIndex: number): CronParseResult {
    return new CronParseResult(false, failure, segmentIndex, null, null, null, null, null,
      CronDescription.none(), false);
  }
}

/** 「接下来 N 次执行时间」的结果 */
export class CronNextRunsResult {
  readonly ok: boolean;
  /** 执行时间（本地时区），升序 */
  readonly runs: Date[];
  /** 在搜索窗口内一次都不会成立（例如「2 月 30 日」） */
  readonly neverMatches: boolean;

  constructor(ok: boolean, runs: Date[], neverMatches: boolean) {
    this.ok = ok;
    this.runs = runs;
    this.neverMatches = neverMatches;
  }
}

/** 搜索窗口：8 年。闰年 2/29 的最坏间隔是 8 年（1896→1904 这类世纪年断档），取它刚好够 */
const SEARCH_DAYS: number = 366 * 8 + 3;

/** 单次请求的最大次数：界面一次列不下更多，也避免用户输个 10000 让页面卡住 */
export const CRON_MAX_RUNS: number = 20;

const MONTH_NAMES: string[] = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

const WEEKDAY_NAMES: string[] = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

// 月份与星期的**展示名**已移到 UI 层（CronMessages.ets）。
// 它们是文案（「1 月」/ 'January'），而纯逻辑层不能 import ArkUI 的 $r()。
// 这里只保留解析用的**缩写表**（JAN/MON 是 cron 语法的输入，不是文案）。

/** cron 段的标识（用于让 UI 层补上「分钟」/「小时」这类段名） */
export enum CronFieldKey {
  MINUTE = 'minute',
  HOUR = 'hour',
  DAY_OF_MONTH = 'day_of_month',
  MONTH = 'month',
  DAY_OF_WEEK = 'day_of_week'
}

/** 单段解析失败的原因码（段名单独给，见 CronFieldKey） */
export enum CronFieldError {
  NONE = 'none',
  /** 段为空 */
  EMPTY = 'empty',
  /** 步长必须是正整数 */
  BAD_STEP = 'bad_step',
  /** 步长必须大于 0 */
  STEP_NOT_POSITIVE = 'step_not_positive',
  /** 逗号分隔的取值里有空的 */
  EMPTY_ITEM = 'empty_item',
  /** 区间写法（a-b）写错了 */
  RANGE_SYNTAX = 'range_syntax',
  /** 取值超出该段允许范围 */
  OUT_OF_RANGE = 'out_of_range',
  /** 区间倒着写 */
  REVERSED_RANGE = 'reversed_range',
  /** 非法取值 */
  BAD_VALUE = 'bad_value',
  /** 一个取值都没解析出来 */
  NO_VALUES = 'no_values'
}

function isDigit(ch: string): boolean {
  return ch >= '0' && ch <= '9';
}

function isAllDigits(text: string): boolean {
  if (text.length === 0) {
    return false;
  }
  for (let i: number = 0; i < text.length; i++) {
    if (!isDigit(text.charAt(i))) {
      return false;
    }
  }
  return true;
}

/** 把单个取值文本解析成数字；名字（JAN/MON）按缩写表换算，失败返回 -1 */
function resolveValue(text: string, names: string[], baseIndex: number): number {
  const upper: string = text.toUpperCase();
  if (names.length > 0) {
    for (let i: number = 0; i < names.length; i++) {
      if (names[i] === upper) {
        return baseIndex + i;
      }
    }
  }
  if (!isAllDigits(text)) {
    return -1;
  }
  const value: number = parseInt(text, 10);
  return isNaN(value) ? -1 : value;
}

/** 单段解析结果（内部用） */
class FieldStep {
  readonly ok: boolean;
  readonly error: CronFieldError;
  readonly args: Array<string>;
  readonly field: CronField | null;

  constructor(ok: boolean, error: CronFieldError, args: Array<string>,
    field: CronField | null) {
    this.ok = ok;
    this.error = error;
    this.args = args;
    this.field = field;
  }
}

/**
 * 解析一个字段。
 *
 * @param raw 字段原文
 * @param name 中文段名（错误信息里用）
 * @param min 允许的最小值
 * @param max 允许的最大值
 * @param names 英文缩写表（月份 12 个 / 星期 7 个；其余传空表）
 * @param baseIndex 缩写表对应的第一个数值（月份 1、星期 0）
 * @param allowSeven 是否把 7 当作周日（只有星期段）
 */
function parseField(raw: string, fieldKey: CronFieldKey, min: number, max: number, names: string[],
  baseIndex: number, allowSeven: boolean): FieldStep {
  const text: string = raw.trim();
  if (text.length === 0) {
    return new FieldStep(false, CronFieldError.EMPTY, [], null);
  }
  const slashIndex: number = text.indexOf('/');
  let step: number = 0;
  let body: string = text;
  if (slashIndex >= 0) {
    body = text.substring(0, slashIndex);
    const stepText: string = text.substring(slashIndex + 1);
    if (!isAllDigits(stepText)) {
      return new FieldStep(false, CronFieldError.BAD_STEP, [text], null);
    }
    step = parseInt(stepText, 10);
    if (step <= 0) {
      return new FieldStep(false, CronFieldError.STEP_NOT_POSITIVE, [text], null);
    }
  }

  const values: number[] = [];
  const seen: boolean[] = [];
  for (let i: number = 0; i <= max + 1; i++) {
    seen.push(false);
  }

  const isWildcard: boolean = body === '*';
  const items: string[] = body.split(',');
  for (let i: number = 0; i < items.length; i++) {
    const item: string = items[i].trim();
    if (item.length === 0) {
      return new FieldStep(false, CronFieldError.EMPTY_ITEM, [], null);
    }
    let from: number = 0;
    let to: number = 0;
    if (item === '*') {
      from = min;
      to = max;
    } else {
      const dashIndex: number = item.indexOf('-');
      if (dashIndex > 0) {
        const startValue: number = resolveValue(item.substring(0, dashIndex).trim(), names, baseIndex);
        const endValue: number = resolveValue(item.substring(dashIndex + 1).trim(), names, baseIndex);
        if (startValue < 0 || endValue < 0) {
          return new FieldStep(false, CronFieldError.RANGE_SYNTAX, [item], null);
        }
        if (startValue < min || startValue > max || endValue < min || endValue > max) {
          return new FieldStep(false, CronFieldError.OUT_OF_RANGE,
      [String(min), String(max), item], null);
        }
        if (startValue > endValue) {
          return new FieldStep(false, CronFieldError.REVERSED_RANGE, [item], null);
        }
        from = startValue;
        to = endValue;
      } else {
        const single: number = resolveValue(item, names, baseIndex);
        if (single < 0) {
          return new FieldStep(false, CronFieldError.BAD_VALUE, [item], null);
        }
        if (single < min || single > max) {
          return new FieldStep(false, CronFieldError.OUT_OF_RANGE,
      [String(min), String(max), item], null);
        }
        // A/N 语义按「从 A 到最大值，每隔 N」处理（与 Vixie cron 的常见扩展一致）
        from = single;
        to = step > 0 ? max : single;
      }
    }
    const increment: number = step > 0 ? step : 1;
    for (let value: number = from; value <= to; value += increment) {
      let normalized: number = value;
      if (allowSeven && normalized === 7) {
        normalized = 0;
      }
      seen[normalized] = true;
    }
  }

  for (let value: number = min; value <= max; value++) {
    let normalized: number = value;
    if (allowSeven && normalized === 7) {
      normalized = 0;
    }
    if (normalized <= max && seen[normalized]) {
      // 0 与 7 都表示周日：只保留一个
      let duplicated: boolean = false;
      for (let k: number = 0; k < values.length; k++) {
        if (values[k] === normalized) {
          duplicated = true;
        }
      }
      if (!duplicated) {
        values.push(normalized);
      }
    }
  }
  if (values.length === 0) {
    return new FieldStep(false, CronFieldError.NO_VALUES, [text], null);
  }
  // 注意参数顺序：fieldKey, raw, values, isWildcard, step —— 少传一个 raw 会让后面全部错位，
  // 表现为「* 展开出的 values 变成空数组」，于是任何表达式都算不出执行时间。
  return new FieldStep(true, CronFieldError.NONE, [],
    new CronField(fieldKey, raw, values, isWildcard, step));
}

/** 把数字列表拼成文案 */
/**
 * 生成人话描述的**结构**（措辞在 UI 层）。
 *
 * 原先这里直接拼中文（'每 5 分钟（9、17 点内）'）。改成结构之后，
 * 「几点」「哪几天」这些数字原样带出去，由每种语言自己决定怎么摆、用什么连接词。
 */
function buildDescription(minutes: CronField, hours: CronField, daysOfMonth: CronField,
  months: CronField, daysOfWeek: CronField): CronDescription {
  let basis: CronTimeBasis = CronTimeBasis.NONE;
  if (minutes.isWildcard && minutes.step === 0) {
    basis = CronTimeBasis.EVERY_MINUTE;
  } else if (minutes.step > 0 && minutes.isWildcard) {
    basis = CronTimeBasis.EVERY_N_MINUTES;
  } else if (hours.isWildcard) {
    basis = CronTimeBasis.AT_MINUTE_OF_EVERY_HOUR;
  } else {
    basis = CronTimeBasis.AT_TIMES;
  }
  // 日与周都不是 * 时是「或」关系，文案必须跟着写「或」，
  // 否则描述会与实际执行时间矛盾
  const dayFieldsAreOr: boolean = !daysOfMonth.isWildcard && !daysOfWeek.isWildcard;
  return new CronDescription(basis, minutes.step, minutes.values, hours.values,
    !hours.isWildcard, months.values, daysOfMonth.values, daysOfWeek.values,
    !months.isWildcard, !daysOfMonth.isWildcard, !daysOfWeek.isWildcard, dayFieldsAreOr);
}
/**
 * 解析 5 段 cron 表达式。
 *
 * @param expression 表达式原文，按空白切段
 */
export function parseCronExpression(expression: string): CronParseResult {
  const trimmed: string = expression.trim();
  if (trimmed.length === 0) {
    return CronParseResult.failure(CronParseFailure.of(CronParseFailureCode.EMPTY, []), -1);
  }
  const segments: string[] = trimmed.split(' ');
  const fields: string[] = [];
  for (let i: number = 0; i < segments.length; i++) {
    if (segments[i].length > 0) {
      fields.push(segments[i]);
    }
  }
  if (fields.length !== 5) {
    const codes: Array<CronParseFailureCode> = [CronParseFailureCode.WRONG_SEGMENT_COUNT];
    if (fields.length === 6) {
      codes.push(CronParseFailureCode.SIX_SEGMENTS);
    }
    if (fields.length === 1 && fields[0].charAt(0) === '@') {
      codes.push(CronParseFailureCode.ALIAS);
    }
    return CronParseResult.failure(
      new CronParseFailure(codes, [String(fields.length)], CronFieldError.NONE,
        CronFieldKey.MINUTE, []), -1);
  }

  const minuteStep: FieldStep = parseField(fields[0], CronFieldKey.MINUTE, 0, 59, [], 0, false);
  if (!minuteStep.ok || minuteStep.field === null) {
    return CronParseResult.failure(
      CronParseFailure.ofField(minuteStep.error, CronFieldKey.MINUTE, minuteStep.args), 0);
  }
  const hourStep: FieldStep = parseField(fields[1], CronFieldKey.HOUR, 0, 23, [], 0, false);
  if (!hourStep.ok || hourStep.field === null) {
    return CronParseResult.failure(
      CronParseFailure.ofField(hourStep.error, CronFieldKey.HOUR, hourStep.args), 1);
  }
  const dayStep: FieldStep = parseField(fields[2], CronFieldKey.DAY_OF_MONTH, 1, 31, [], 1, false);
  if (!dayStep.ok || dayStep.field === null) {
    return CronParseResult.failure(
      CronParseFailure.ofField(dayStep.error, CronFieldKey.DAY_OF_MONTH, dayStep.args), 2);
  }
  const monthStep: FieldStep = parseField(fields[3], CronFieldKey.MONTH, 1, 12, MONTH_NAMES, 1, false);
  if (!monthStep.ok || monthStep.field === null) {
    return CronParseResult.failure(
      CronParseFailure.ofField(monthStep.error, CronFieldKey.MONTH, monthStep.args), 3);
  }
  const weekdayStep: FieldStep = parseField(fields[4], CronFieldKey.DAY_OF_WEEK, 0, 7, WEEKDAY_NAMES, 0, true);
  if (!weekdayStep.ok || weekdayStep.field === null) {
    return CronParseResult.failure(
      CronParseFailure.ofField(weekdayStep.error, CronFieldKey.DAY_OF_WEEK, weekdayStep.args), 4);
  }

  const minutes: CronField = minuteStep.field;
  const hours: CronField = hourStep.field;
  const daysOfMonth: CronField = dayStep.field;
  const months: CronField = monthStep.field;
  const daysOfWeek: CronField = weekdayStep.field;
  const bothDayFields: boolean = !daysOfMonth.isWildcard && !daysOfWeek.isWildcard;
  return new CronParseResult(true, CronParseFailure.none(), -1, minutes, hours, daysOfMonth,
    months, daysOfWeek, buildDescription(minutes, hours, daysOfMonth, months, daysOfWeek),
    bothDayFields);
}

/**
 * 判断某一天是否满足「日」与「星期」两个字段。
 *
 * 单独抽出来是因为这里的规则与直觉相反：**两者都不是 \* 时是「或」**。
 * 写成一个可直接单测的函数，比埋在两处循环里可靠得多。
 *
 * @param day 当月第几天（1-31）
 * @param weekday 星期（0=周日）
 */
export function cronDayMatches(day: number, weekday: number, daysOfMonth: CronField,
  daysOfWeek: CronField): boolean {
  if (daysOfMonth.isWildcard && daysOfWeek.isWildcard) {
    return true;
  }
  if (daysOfMonth.isWildcard) {
    return daysOfWeek.contains(weekday);
  }
  if (daysOfWeek.isWildcard) {
    return daysOfMonth.contains(day);
  }
  return daysOfMonth.contains(day) || daysOfWeek.contains(weekday);
}

/**
 * 计算接下来 N 次执行时间（本地时区）。
 *
 * 为什么是「逐日筛选 + 当日笛卡尔积」而不是「逐分钟推进」：
 * `0 0 29 2 *`（闰年 2 月 29 日）下一次可能在 4 年之后，逐分钟要走 200 万步；
 * 逐日最多走 8 年的天数，且每天只在命中时展开时/分组合。
 */
export function nextCronRuns(expression: string, fromMilliseconds: number, count: number): CronNextRunsResult {
  const parsed: CronParseResult = parseCronExpression(expression);
  if (!parsed.ok || parsed.minutes === null || parsed.hours === null || parsed.daysOfMonth === null
    || parsed.months === null || parsed.daysOfWeek === null) {
    return new CronNextRunsResult(false, [], false);
  }
  const minutes: CronField = parsed.minutes;
  const hours: CronField = parsed.hours;
  const daysOfMonth: CronField = parsed.daysOfMonth;
  const months: CronField = parsed.months;
  const daysOfWeek: CronField = parsed.daysOfWeek;

  const wanted: number = count <= 0 ? 5 : (count > CRON_MAX_RUNS ? CRON_MAX_RUNS : count);
  const runs: Date[] = [];

  // 从「from 之后的第一个整分钟」起算：cron 的语义是严格晚于当前时刻
  const first: Date = new Date(fromMilliseconds);
  first.setSeconds(0, 0);
  first.setMinutes(first.getMinutes() + 1);
  const firstYear: number = first.getFullYear();
  const firstMonth: number = first.getMonth();
  const firstDay: number = first.getDate();

  for (let dayOffset: number = 0; dayOffset <= SEARCH_DAYS && runs.length < wanted; dayOffset++) {
    const day: Date = new Date(firstYear, firstMonth, firstDay + dayOffset, 0, 0, 0, 0);
    const month: number = day.getMonth() + 1;
    if (!months.contains(month)) {
      continue;
    }
    if (!cronDayMatches(day.getDate(), day.getDay(), daysOfMonth, daysOfWeek)) {
      continue;
    }
    for (let i: number = 0; i < hours.values.length && runs.length < wanted; i++) {
      for (let j: number = 0; j < minutes.values.length && runs.length < wanted; j++) {
        const candidate: Date = new Date(day.getFullYear(), day.getMonth(), day.getDate(),
          hours.values[i], minutes.values[j], 0, 0);
        const milliseconds: number = candidate.getTime();
        if (milliseconds <= fromMilliseconds) {
          continue;
        }
        if (runs.length > 0 && milliseconds <= runs[runs.length - 1].getTime()) {
          // 夏令时切换当天可能出现重复/回退的时刻，保证结果严格递增
          continue;
        }
        runs.push(candidate);
      }
    }
  }

  if (runs.length === 0) {
    return new CronNextRunsResult(true, [], true);
  }
  return new CronNextRunsResult(true, runs, false);
}

/**
 * 把日期格式化成 'YYYY-MM-DD HH:mm'。
 *
 * 星期名不再由这里拼出（它是文案，归 UI 层）——页面用 clockWeekday(date.getDay())。
 */
export function formatCronRun(date: Date): string {
  const year: number = date.getFullYear();
  const month: number = date.getMonth() + 1;
  const day: number = date.getDate();
  const hour: number = date.getHours();
  const minute: number = date.getMinutes();
  return String(year) + '-' + (month < 10 ? '0' + String(month) : String(month))
    + '-' + (day < 10 ? '0' + String(day) : String(day))
    + ' ' + (hour < 10 ? '0' + String(hour) : String(hour))
    + ':' + (minute < 10 ? '0' + String(minute) : String(minute));
}