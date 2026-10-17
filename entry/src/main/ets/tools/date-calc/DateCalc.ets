/**
 * 日期计算的纯逻辑实现（公历）。
 *
 * ## 为什么不直接用 Date 对象做减法
 *
 * `new Date(2024, 2, 1) - new Date(2024, 1, 1)` 这种写法在**有夏令时的时区**上会得到
 * 23 小时或 25 小时，除以 86400000 之后是 0.958 或 1.04 天——四舍五入就开始出错。
 * 所以这里把日期先换算成「儒略式日序数」（自 1970-01-01 起的天数，纯整数），
 * 差值、加减法全在整数域完成：**与时区、夏令时完全无关**，也就能在任何机器上得到同样的结果。
 *
 * 日序数算法用的是 Howard Hinnant 的 `days_from_civil` / `civil_from_days`
 * （proleptic Gregorian，公元 1-9999 年），这是被广泛验证过的实现。
 *
 * @module tools/date-calc/DateCalc
 */

import { NGFLocalizedText } from '../../core/ToolModel';

/** 支持的最小年份 */
export const DATE_MIN_YEAR: number = 1;

/** 支持的最大年份 */
export const DATE_MAX_YEAR: number = 9999;

/** 一个公历日期（月为 1-12，日为 1-31） */
export class NGFDate {
  readonly year: number;
  readonly month: number;
  readonly day: number;

  constructor(year: number, month: number, day: number) {
    this.year = year;
    this.month = month;
    this.day = day;
  }
}

/** 日期解析失败的原因码 */
export enum DateParseFailure {
  NONE = 'none',
  /** 空输入 */
  EMPTY = 'empty',
  /** 整体格式认不出来 */
  UNRECOGNIZED = 'unrecognized',
  /** 含非数字字符 */
  NON_DIGIT = 'non_digit',
  /** 年份超出可表示范围 */
  YEAR_RANGE = 'year_range',
  /** 月份不在 1-12 */
  MONTH_RANGE = 'month_range',
  /** 该月没有这一天（例如 4 月 31 日） */
  DAY_RANGE = 'day_range'
}

/** 日期解析结果 */
export class DateParseResult {
  readonly ok: boolean;
  /** 失败原因；成功时为 NONE（**永不为 null**） */
  readonly failure: DateParseFailure;
  /** 资源文案的占位符参数（顺序须与资源文案里 %s 一致） */
  readonly args: Array<string>;
  readonly date: NGFDate | null;

  constructor(ok: boolean, failure: DateParseFailure, args: Array<string>, date: NGFDate | null) {
    this.ok = ok;
    this.failure = failure;
    this.args = args;
    this.date = date;
  }

  static success(date: NGFDate): DateParseResult {
    return new DateParseResult(true, DateParseFailure.NONE, [], date);
  }

  static failure(failure: DateParseFailure, args: Array<string>): DateParseResult {
    return new DateParseResult(false, failure, args, null);
  }
}

/** 间隔计算里是哪一侧的日期有问题 */
export enum DateDiffField {
  START = 'start',
  END = 'end'
}

/**
 * 间隔计算的失败原因。
 *
 * 它比别的失败复杂一点：失败其实是**某一侧日期解析失败**，
 * 所以除了「是哪一侧」还要带着内层的解析失败原因，
 * 页面才能给出「起始日期：月份必须在 1-12 之间」这种带上下文的提示。
 * 内层失败单独建类而不是复用 string，正是为了让这句话可翻译。
 */
export class DateDiffFailure {
  readonly field: DateDiffField;
  readonly innerFailure: DateParseFailure;
  readonly innerArgs: Array<string>;

  constructor(field: DateDiffField, innerFailure: DateParseFailure, innerArgs: Array<string>) {
    this.field = field;
    this.innerFailure = innerFailure;
    this.innerArgs = innerArgs;
  }

  static none(): DateDiffFailure {
    return new DateDiffFailure(DateDiffField.START, DateParseFailure.NONE, []);
  }
}

/** 间隔计算的结果 */
export class DateDiffResult {
  readonly ok: boolean;
  readonly failure: DateDiffFailure;
  /** 相差天数（end - start，可为负） */
  readonly days: number;
  /** 相差工作日数（不含起算当天，工作日口径可选是否排除周末） */
  readonly workdays: number;
  /** 起止是否倒置（end 早于 start） */
  readonly reversed: boolean;
  /** 起止是否同一天 */
  readonly sameDay: boolean;

  constructor(ok: boolean, failure: DateDiffFailure, days: number, workdays: number,
    reversed: boolean, sameDay: boolean) {
    this.ok = ok;
    this.failure = failure;
    this.days = days;
    this.workdays = workdays;
    this.reversed = reversed;
    this.sameDay = sameDay;
  }

  static failure(field: DateDiffField, innerFailure: DateParseFailure,
    innerArgs: Array<string>): DateDiffResult {
    return new DateDiffResult(false, new DateDiffFailure(field, innerFailure, innerArgs),
      0, 0, false, false);
  }
}

/** 日期加减失败的原因码 */
export enum DateShiftFailure {
  NONE = 'none',
  /** 天数不是整数 */
  DAYS_NOT_INTEGER = 'days_not_integer',
  /** 月数不是整数 */
  MONTHS_NOT_INTEGER = 'months_not_integer',
  /** 年数不是整数 */
  YEARS_NOT_INTEGER = 'years_not_integer',
  /** 结果超出可表示年份范围 */
  OUT_OF_RANGE = 'out_of_range',
  /** 基准日期本身就解析不了（内层失败见 innerFailure） */
  BAD_BASE_DATE = 'bad_base_date'
}

/** 日期加减的结果 */
export class DateShiftResult {
  readonly ok: boolean;
  /** 失败原因；成功时为 NONE（**永不为 null**） */
  readonly failure: DateShiftFailure;
  /** 资源文案的占位符参数 */
  readonly args: Array<string>;
  readonly date: NGFDate | null;
  /** 是否因为目标月没有这一天而被夹到月末（例如 1/31 加一个月） */
  readonly clamped: boolean;
  /** 当 failure 是 BAD_BASE_DATE 时，这是基准日期解析失败的具体原因 */
  readonly innerFailure: DateParseFailure;
  readonly innerArgs: Array<string>;

  constructor(ok: boolean, failure: DateShiftFailure, args: Array<string>, date: NGFDate | null,
    clamped: boolean, innerFailure: DateParseFailure, innerArgs: Array<string>) {
    this.ok = ok;
    this.failure = failure;
    this.args = args;
    this.date = date;
    this.clamped = clamped;
    this.innerFailure = innerFailure;
    this.innerArgs = innerArgs;
  }

  static success(date: NGFDate, clamped: boolean): DateShiftResult {
    return new DateShiftResult(true, DateShiftFailure.NONE, [], date, clamped,
      DateParseFailure.NONE, []);
  }

  static failure(failure: DateShiftFailure, args: Array<string>): DateShiftResult {
    return new DateShiftResult(false, failure, args, null, false, DateParseFailure.NONE, []);
  }

  /**
   * 基准日期解析失败。
   *
   * 单独一个构造入口，因为这与「加减数量不合法」是两类问题：
   * 前者要转述内层的解析失败原因，后者是本地原因。
   */
  static baseDateFailure(parsed: DateParseResult): DateShiftResult {
    return new DateShiftResult(false, DateShiftFailure.BAD_BASE_DATE, [], null, false,
      parsed.failure, parsed.args);
  }
}

/**
 * 星期的展示名（双语数据）。
 *
 * 这是**内容数据**而不是页面文案，所以走 NGFLocalizedText 而不是资源键：
 * 它在纯逻辑层，而纯逻辑层不能 import ArkUI 的 \`$r()\`。
 * 与 \`subnet-calc\` 的保留网段名、\`color-convert\` 的配色方案名同一套机制。
 */
const WEEKDAY_LOCALIZED: NGFLocalizedText[] = [
  new NGFLocalizedText('周日', 'Sun'),
  new NGFLocalizedText('周一', 'Mon'),
  new NGFLocalizedText('周二', 'Tue'),
  new NGFLocalizedText('周三', 'Wed'),
  new NGFLocalizedText('周四', 'Thu'),
  new NGFLocalizedText('周五', 'Fri'),
  new NGFLocalizedText('周六', 'Sat')
];

/** 是否闰年（公历规则：4 年一闰、100 年不闰、400 年再闰） */
export function isLeapYear(year: number): boolean {
  if (year % 400 === 0) {
    return true;
  }
  if (year % 100 === 0) {
    return false;
  }
  return year % 4 === 0;
}

/** 某年某月的天数（month 为 1-12） */
export function daysInMonth(year: number, month: number): number {
  if (month === 2) {
    return isLeapYear(year) ? 29 : 28;
  }
  if (month === 4 || month === 6 || month === 9 || month === 11) {
    return 30;
  }
  return 31;
}

/** 年份是否在支持范围内 */
export function isValidYear(year: number): boolean {
  return !isNaN(year) && Math.floor(year) === year && year >= DATE_MIN_YEAR && year <= DATE_MAX_YEAR;
}

/**
 * 公历日期 → 自 1970-01-01 起的天数（可为负）。
 *
 * 这就是所有差值/加减法的统一底座：整数运算不存在时区与夏令时的坑。
 */
export function toDayNumber(date: NGFDate): number {
  let year: number = date.year;
  const month: number = date.month;
  if (month <= 2) {
    year -= 1;
  }
  const era: number = Math.floor(year / 400);
  const yearOfEra: number = year - era * 400;
  const shiftedMonth: number = month > 2 ? month - 3 : month + 9;
  const dayOfYear: number = Math.floor((153 * shiftedMonth + 2) / 5) + date.day - 1;
  const dayOfEra: number = yearOfEra * 365 + Math.floor(yearOfEra / 4) - Math.floor(yearOfEra / 100) + dayOfYear;
  return era * 146097 + dayOfEra - 719468;
}

/** 自 1970-01-01 起的天数 → 公历日期 */
export function fromDayNumber(dayNumber: number): NGFDate {
  const shifted: number = dayNumber + 719468;
  const era: number = Math.floor(shifted / 146097);
  const dayOfEra: number = shifted - era * 146097;
  const yearOfEra: number = Math.floor((dayOfEra - Math.floor(dayOfEra / 1460)
    + Math.floor(dayOfEra / 36524) - Math.floor(dayOfEra / 146096)) / 365);
  const year: number = yearOfEra + era * 400;
  const dayOfYear: number = dayOfEra - (365 * yearOfEra + Math.floor(yearOfEra / 4) - Math.floor(yearOfEra / 100));
  const shiftedMonth: number = Math.floor((5 * dayOfYear + 2) / 153);
  const day: number = dayOfYear - Math.floor((153 * shiftedMonth + 2) / 5) + 1;
  const month: number = shiftedMonth < 10 ? shiftedMonth + 3 : shiftedMonth - 9;
  if (month <= 2) {
    return new NGFDate(year + 1, month, day);
  }
  return new NGFDate(year, month, day);
}

/** 星期（0=周日），与 JS Date#getDay 同口径 */
export function weekdayOf(date: NGFDate): number {
  const dayNumber: number = toDayNumber(date);
  return ((dayNumber % 7) + 4 + 7) % 7;
}

/** 星期的展示名（越界返回空串，而不是 undefined） */
export function weekdayLabel(weekday: number, locale: string): string {
  if (weekday < 0 || weekday > 6) {
    return '';
  }
  return WEEKDAY_LOCALIZED[weekday].forLocale(locale);
}

/** 是否为工作日（周一至周五；不含法定节假日） */
export function isWorkday(date: NGFDate): boolean {
  const weekday: number = weekdayOf(date);
  return weekday >= 1 && weekday <= 5;
}

/** 格式化 'YYYY-MM-DD' */
export function formatDate(date: NGFDate): string {
  return pad4(date.year) + '-' + pad2(date.month) + '-' + pad2(date.day);
}

/** 格式化 'YYYY-MM-DD 周X' / 'YYYY-MM-DD Mon' */
export function formatDateWithWeekday(date: NGFDate, locale: string): string {
  return formatDate(date) + ' ' + weekdayLabel(weekdayOf(date), locale);
}

function pad2(value: number): string {
  const text: string = String(value);
  return text.length >= 2 ? text : '0' + text;
}

function pad4(value: number): string {
  let text: string = String(value);
  while (text.length < 4) {
    text = '0' + text;
  }
  return text;
}

function isAllDigits(text: string): boolean {
  if (text.length === 0) {
    return false;
  }
  for (let i: number = 0; i < text.length; i++) {
    const code: number = text.charCodeAt(i);
    if (code < 48 || code > 57) {
      return false;
    }
  }
  return true;
}

/**
 * 解析日期文本。
 *
 * 接受 `YYYY-MM-DD`、`YYYY/M/D`、`YYYY.M.D` 与 8 位连写 `YYYYMMDD`。
 * **严格校验真实存在**：`2023-02-29` 会报错并说明该月只有 28 天——
 * 静默把它当成 3 月 1 日是最常见、也最容易被忽略的错误来源。
 */
export function parseDateText(text: string): DateParseResult {
  const trimmed: string = text.trim();
  if (trimmed.length === 0) {
    return DateParseResult.failure(DateParseFailure.EMPTY, []);
  }
  let normalized: string = trimmed;
  for (let i: number = 0; i < 3; i++) {
    const separator: string = i === 0 ? '/' : (i === 1 ? '.' : '年'); // i18n-parser-literal
    normalized = normalized.split(separator).join('-');
  }
  normalized = normalized.split('月').join('-'); // i18n-parser-literal
  normalized = normalized.split('日').join(''); // i18n-parser-literal
  const parts: string[] = normalized.split('-');
  let year: number = 0;
  let month: number = 0;
  let day: number = 0;
  if (parts.length === 1) {
    const digits: string = parts[0];
    if (digits.length !== 8 || !isAllDigits(digits)) {
      return DateParseResult.failure(DateParseFailure.UNRECOGNIZED, [text]);
    }
    year = parseInt(digits.substring(0, 4), 10);
    month = parseInt(digits.substring(4, 6), 10);
    day = parseInt(digits.substring(6, 8), 10);
  } else if (parts.length === 3) {
    if (!isAllDigits(parts[0]) || !isAllDigits(parts[1]) || !isAllDigits(parts[2])) {
      return DateParseResult.failure(DateParseFailure.NON_DIGIT, [text]);
    }
    year = parseInt(parts[0], 10);
    month = parseInt(parts[1], 10);
    day = parseInt(parts[2], 10);
  } else {
    return DateParseResult.failure(DateParseFailure.UNRECOGNIZED, [text]);
  }
  if (!isValidYear(year)) {
    return DateParseResult.failure(DateParseFailure.YEAR_RANGE,
      [String(DATE_MIN_YEAR), String(DATE_MAX_YEAR)]);
  }
  if (month < 1 || month > 12) {
    return DateParseResult.failure(DateParseFailure.MONTH_RANGE, []);
  }
  const lastDay: number = daysInMonth(year, month);
  if (day < 1 || day > lastDay) {
    return DateParseResult.failure(DateParseFailure.DAY_RANGE,
      [String(year), String(month), String(lastDay), String(day)]);
  }
  return DateParseResult.success(new NGFDate(year, month, day));
}

/**
 * 计算两个日期之间的天数与工作日数。
 *
 * 工作日口径写死为「**不含起算当天、包含结束当天**」（即 (start, end]），
 * 并在页面 limitation 里说明：这样「周一到周五」是 4 个工作日，符合排期直觉。
 * 不含法定节假日——那需要一份逐年维护的节假日表，本工具不内置。
 */
export function diffDates(startText: string, endText: string, excludeWeekends: boolean): DateDiffResult {
  const start: DateParseResult = parseDateText(startText);
  if (!start.ok || start.date === null) {
    return DateDiffResult.failure(DateDiffField.START, start.failure, start.args);
  }
  const end: DateParseResult = parseDateText(endText);
  if (!end.ok || end.date === null) {
    return DateDiffResult.failure(DateDiffField.END, end.failure, end.args);
  }
  const startDay: number = toDayNumber(start.date);
  const endDay: number = toDayNumber(end.date);
  const days: number = endDay - startDay;
  const reversed: boolean = days < 0;
  // 工作日数只取决于「区间里有哪些天」，与遍历方向无关；区间取 (min, max]
  const lowDay: number = startDay < endDay ? startDay : endDay;
  const highDay: number = startDay < endDay ? endDay : startDay;
  const span: number = highDay - lowDay;
  let workdays: number = 0;
  if (span > 0) {
    if (!excludeWeekends) {
      workdays = span;
    } else {
      // 每连续 7 天里恰有 5 个工作日，先按整周算，剩下的不足一周再逐天判断——
      // 逐天遍历在「公元 1 年 → 9999 年」这种跨度上要走 365 万步，界面会明显卡顿。
      const fullWeeks: number = Math.floor(span / 7);
      const remainder: number = span - fullWeeks * 7;
      workdays = fullWeeks * 5;
      for (let offset: number = 1; offset <= remainder; offset++) {
        if (isWorkday(fromDayNumber(lowDay + offset))) {
          workdays += 1;
        }
      }
    }
  }
  // 工作日数与天数保持同一符号：倒置的区间两者都是负的，界面不必再解释方向
  return new DateDiffResult(true, DateDiffFailure.none(), days,
    reversed ? -workdays : workdays, reversed, days === 0);
}

/** 在日期上加减天数 */
export function addDaysToDate(text: string, days: number): DateShiftResult {
  const parsed: DateParseResult = parseDateText(text);
  if (!parsed.ok || parsed.date === null) {
    return DateShiftResult.baseDateFailure(parsed);
  }
  if (isNaN(days) || Math.floor(days) !== days) {
    return DateShiftResult.failure(DateShiftFailure.DAYS_NOT_INTEGER, []);
  }
  const target: NGFDate = fromDayNumber(toDayNumber(parsed.date) + days);
  if (!isValidYear(target.year)) {
    return DateShiftResult.failure(DateShiftFailure.OUT_OF_RANGE,
      [String(DATE_MIN_YEAR), String(DATE_MAX_YEAR)]);
  }
  return DateShiftResult.success(target, false);
}

/** 在日期上加减月数；目标月没有这一天时夹到该月最后一天并标记 clamped */
export function addMonthsToDate(text: string, months: number): DateShiftResult {
  const parsed: DateParseResult = parseDateText(text);
  if (!parsed.ok || parsed.date === null) {
    return DateShiftResult.baseDateFailure(parsed);
  }
  if (isNaN(months) || Math.floor(months) !== months) {
    return DateShiftResult.failure(DateShiftFailure.MONTHS_NOT_INTEGER, []);
  }
  const totalMonths: number = parsed.date.year * 12 + (parsed.date.month - 1) + months;
  const year: number = Math.floor(totalMonths / 12);
  const month: number = totalMonths - year * 12 + 1;
  if (!isValidYear(year)) {
    return DateShiftResult.failure(DateShiftFailure.OUT_OF_RANGE,
      [String(DATE_MIN_YEAR), String(DATE_MAX_YEAR)]);
  }
  const lastDay: number = daysInMonth(year, month);
  const clamped: boolean = parsed.date.day > lastDay;
  const day: number = clamped ? lastDay : parsed.date.day;
  const target: NGFDate = new NGFDate(year, month, day);
  return DateShiftResult.success(target, clamped);
}

/** 在日期上加减年数；2/29 加非闰年时夹到 2/28 并标记 clamped */
export function addYearsToDate(text: string, years: number): DateShiftResult {
  const parsed: DateParseResult = parseDateText(text);
  if (!parsed.ok || parsed.date === null) {
    return DateShiftResult.baseDateFailure(parsed);
  }
  if (isNaN(years) || Math.floor(years) !== years) {
    return DateShiftResult.failure(DateShiftFailure.YEARS_NOT_INTEGER, []);
  }
  const year: number = parsed.date.year + years;
  if (!isValidYear(year)) {
    return DateShiftResult.failure(DateShiftFailure.OUT_OF_RANGE,
      [String(DATE_MIN_YEAR), String(DATE_MAX_YEAR)]);
  }
  const lastDay: number = daysInMonth(year, parsed.date.month);
  const clamped: boolean = parsed.date.day > lastDay;
  const day: number = clamped ? lastDay : parsed.date.day;
  const target: NGFDate = new NGFDate(year, parsed.date.month, day);
  return DateShiftResult.success(target, clamped);
}