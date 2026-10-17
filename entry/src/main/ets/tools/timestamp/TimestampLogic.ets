/**
 * 时间戳工具的**纯逻辑层**。
 *
 * ## 时区为什么不用系统时区 API
 *
 * 真机上有 @ohos.intl 可以拿到完整时区库，但纯逻辑层不能 import 任何设备能力
 * （否则单测就跑不起来）。这里改用**固定偏移**的做法：把毫秒数加上偏移量后
 * 用 Date 的 getUTC* 系列读取，等价于「把这块表调到那个时区的墙上时间」。
 *
 * 代价说清楚：固定偏移**不处理夏令时**。巴黎在夏天实际是 UTC+2，本工具仍按 UTC+1 显示。
 * 这不是疏忽而是取舍——要正确支持夏令时需要一整套时区数据库，
 * 而本工具的核心用途是「把这个时间戳换成我看得懂的日期」，固定偏移已经够用，
 * 且结果在任何设备上完全一致（可测）。
 *
 * ## 秒 / 毫秒的自动识别规则
 *
 * - 10 位以内 → 秒（覆盖 1970-2286）
 * - 11 位及以上 → 毫秒
 * 为什么 11 位算毫秒：11 位的数字当秒解释会得到公元 5138 年，那不是任何人的意图；
 * 而当毫秒解释是 1970 年 4 月——虽然也少见，但至少落在合理区间。
 * 已知盲区：1970 年头三个月的毫秒时间戳（10 位）会被当成秒，见 limitation 说明。
 *
 * @module tools/timestamp/TimestampLogic
 */

import { NGFLocalizedText } from '../../core/ToolModel';

/** Date 能表示的最大毫秒数绝对值（±8.64e15，约公元前 271821 年到公元 275760 年） */
/**
 * 时间戳最多允许的位数。
 *
 * 提出成常量是因为它同时出现在**判断**（长度检查）与**文案参数**
 * （「最多 N 位」）里，两处各写一个 16 迟早会漂移。
 */
export const TIMESTAMP_MAX_DIGITS: number = 16;

export const TIMESTAMP_MAX_MS: number = 8640000000000000;

/** 时间戳单位 */
export enum TimestampUnit {
  SECONDS = 'seconds',
  MILLISECONDS = 'milliseconds'
}

/** 输入被识别成了什么 */
export enum InterpretKind {
  /** 没有输入 */
  EMPTY = 'empty',
  /** 是一串数字，按时间戳解释 */
  TIMESTAMP = 'timestamp',
  /** 含分隔符，按日期字符串解释 */
  DATE = 'date',
  /** 都无法解释 */
  INVALID = 'invalid'
}

/** 日期各部分（**已按目标时区偏移换算过**的墙上时间） */
export class DateParts {
  readonly year: number;
  readonly month: number;
  readonly day: number;
  readonly hour: number;
  readonly minute: number;
  readonly second: number;
  readonly millisecond: number;
  /** 0=周日 … 6=周六 */
  readonly weekday: number;

  constructor(year: number, month: number, day: number, hour: number, minute: number,
              second: number, millisecond: number, weekday: number) {
    this.year = year;
    this.month = month;
    this.day = day;
    this.hour = hour;
    this.minute = minute;
    this.second = second;
    this.millisecond = millisecond;
    this.weekday = weekday;
  }
}

/** 时间戳解析失败的原因码 */
export enum TimestampFailure {
  NONE = 'none',
  EMPTY = 'empty',
  NOT_DIGITS = 'not_digits',
  TOO_MANY_DIGITS = 'too_many_digits',
  OUT_OF_RANGE = 'out_of_range'
}

/** 时间戳解析结果 */
export class TimestampParseResult {
  readonly ok: boolean;
  readonly milliseconds: number;
  readonly unit: TimestampUnit;
  /** 输入的数字位数（10 位以内=秒，11 位及以上=毫秒） */
  readonly digitCount: number;
  /** 失败原因；成功时为 NONE（**永不为 null**） */
  readonly failure: TimestampFailure;
  /** 资源文案的占位符参数 */
  readonly args: Array<string>;

  constructor(ok: boolean, milliseconds: number, unit: TimestampUnit, digitCount: number,
    failure: TimestampFailure, args: Array<string>) {
    this.ok = ok;
    this.milliseconds = milliseconds;
    this.unit = unit;
    this.digitCount = digitCount;
    this.failure = failure;
    this.args = args;
  }

  static failure(failure: TimestampFailure, args: Array<string>): TimestampParseResult {
    return new TimestampParseResult(false, 0, TimestampUnit.SECONDS, 0, failure, args);
  }
}

/** 日期字符串解析失败的原因码 */
export enum TimestampDateFailure {
  NONE = 'none',
  EMPTY = 'empty',
  ZONE_SUFFIX = 'zone_suffix',
  BAD_DATE_FORMAT = 'bad_date_format',
  BAD_DATE_DIGITS = 'bad_date_digits',
  YEAR_RANGE = 'year_range',
  MONTH_RANGE = 'month_range',
  DAY_RANGE = 'day_range',
  BAD_TIME_FORMAT = 'bad_time_format',
  BAD_MILLIS = 'bad_millis',
  TIME_RANGE = 'time_range',
  OUT_OF_RANGE = 'out_of_range'
}

/** 日期字符串解析结果 */
export class DateParseResult {
  readonly ok: boolean;
  readonly milliseconds: number;
  readonly failure: TimestampDateFailure;
  readonly args: Array<string>;

  constructor(ok: boolean, milliseconds: number, failure: TimestampDateFailure,
    args: Array<string>) {
    this.ok = ok;
    this.milliseconds = milliseconds;
    this.failure = failure;
    this.args = args;
  }

  static failure(failure: TimestampDateFailure, args: Array<string>): DateParseResult {
    return new DateParseResult(false, 0, failure, args);
  }
}

/** 时区选项（固定偏移，不含夏令时） */
export class TimeZoneOption {
  readonly id: string;
  /** 时区名（双语数据，按 locale 取） */
  readonly label: NGFLocalizedText;
  /** 相对 UTC 的分钟偏移；isLocal 为 true 时该值无意义，用 {@link offsetOf} 取 */
  readonly offsetMinutes: number;
  readonly isLocal: boolean;

  constructor(id: string, label: NGFLocalizedText, offsetMinutes: number, isLocal: boolean) {
    this.id = id;
    this.label = label;
    this.offsetMinutes = offsetMinutes;
    this.isLocal = isLocal;
  }
}

/** 时区对照表的一行 */
export class ZoneRow {
  /** 时区名（双语数据，按 locale 取） */
  readonly label: NGFLocalizedText;
  readonly offsetText: string;
  readonly dateTimeText: string;
  /** 星期几（0=周日）。**不是**文本：措辞归 UI 层 */
  readonly weekdayIndex: number;
  readonly isLocal: boolean;

  constructor(label: NGFLocalizedText, offsetText: string, dateTimeText: string,
    weekdayIndex: number, isLocal: boolean) {
    this.label = label;
    this.offsetText = offsetText;
    this.dateTimeText = dateTimeText;
    this.weekdayIndex = weekdayIndex;
    this.isLocal = isLocal;
  }
}

/** 一次输入的双向解释结果，页面只渲染它 */
export class TimestampInterpretation {
  readonly kind: InterpretKind;
  readonly milliseconds: number;
  readonly unit: TimestampUnit;
  /** 秒级时间戳文本 */
  readonly secondsText: string;
  /** 毫秒级时间戳文本 */
  readonly millisecondsText: string;
  /** 在调用方指定时区偏移下的可读日期时间（页面传本地偏移即本地时间） */
  readonly zoneText: string;
  /** UTC 下的可读日期时间，与 zoneText 对照 */
  readonly utcText: string;
  /** 失败原因；成功时为 {@link InterpretFailure.none}（**永不为 null**） */
  readonly failure: InterpretFailure;

  constructor(kind: InterpretKind, milliseconds: number, unit: TimestampUnit, secondsText: string,
              millisecondsText: string, zoneText: string, utcText: string,
              failure: InterpretFailure) {
    this.kind = kind;
    this.milliseconds = milliseconds;
    this.unit = unit;
    this.secondsText = secondsText;
    this.millisecondsText = millisecondsText;
    this.zoneText = zoneText;
    this.utcText = utcText;
    this.failure = failure;
  }
}

/**
 * 「双向解释」的失败原因。
 *
 * 这一层失败**其实是下游的失败**：输入既能当时间戳也能当日期，两条路各有一套失败原因。
 * 所以这里把两套都带上（而不是压成一句 string）——压成字符串就没法翻译了，
 * 因为译文里「时间戳」/「日期」这些词的位置与措辞都不同。
 */
export class InterpretFailure {
  /** true = 来自时间戳解析；false = 来自日期解析 */
  readonly fromTimestamp: boolean;
  readonly timestampFailure: TimestampFailure;
  readonly dateFailure: TimestampDateFailure;
  readonly args: Array<string>;

  constructor(fromTimestamp: boolean, timestampFailure: TimestampFailure,
    dateFailure: TimestampDateFailure, args: Array<string>) {
    this.fromTimestamp = fromTimestamp;
    this.timestampFailure = timestampFailure;
    this.dateFailure = dateFailure;
    this.args = args;
  }

  static none(): InterpretFailure {
    return new InterpretFailure(false, TimestampFailure.NONE, TimestampDateFailure.NONE, []);
  }

  static ofTimestamp(result: TimestampParseResult): InterpretFailure {
    return new InterpretFailure(true, result.failure, TimestampDateFailure.NONE, result.args);
  }

  static ofDate(result: DateParseResult): InterpretFailure {
    return new InterpretFailure(false, TimestampFailure.NONE, result.failure, result.args);
  }
}

const MONTH_DAYS: Array<number> = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
/**
 * 星期的展示名（双语数据）。
 *
 * 与 date-calc 同样处理：它是**内容数据**、住在纯逻辑层，
 * 而纯逻辑层不能 import ArkUI 的 \`$r()\`，所以走 NGFLocalizedText。
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

/** 闰年判断：能被 4 整除但不能被 100 整除，或者能被 400 整除 */
export function isLeapYear(year: number): boolean {
  if (year % 400 === 0) {
    return true;
  }
  if (year % 100 === 0) {
    return false;
  }
  return year % 4 === 0;
}

/** 某年某月的天数；month 为 1-12，越界返回 0 */
export function daysInMonth(year: number, month: number): number {
  if (month < 1 || month > 12) {
    return 0;
  }
  if (month === 2 && isLeapYear(year)) {
    return 29;
  }
  return MONTH_DAYS[month - 1];
}

/** Date 可表示范围判断（同时挡掉 NaN 与 Infinity） */
export function isValidTimestamp(ms: number): boolean {
  if (!Number.isFinite(ms)) {
    return false;
  }
  return Math.abs(ms) <= TIMESTAMP_MAX_MS;
}

/** 现在的毫秒时间戳 */
export function nowMilliseconds(): number {
  return Date.now();
}

/** 秒 → 毫秒 */
export function secondsToMillis(seconds: number): number {
  return seconds * 1000;
}

/** 毫秒 → 秒；按**向下取整**，这样 1969-12-31T23:59:59.999 得到 -1 而不是 0 */
export function millisToSeconds(ms: number): number {
  return Math.floor(ms / 1000);
}

/** 补零到指定宽度 */
export function padNumber(value: number, width: number): string {
  let text: string = Math.abs(value).toString();
  while (text.length < width) {
    text = '0' + text;
  }
  if (value < 0) {
    return '-' + text;
  }
  return text;
}

function isAllDigits(text: string): boolean {
  if (text.length === 0) {
    return false;
  }
  for (let i: number = 0; i < text.length; i++) {
    const ch: string = text.charAt(i);
    if (ch < '0' || ch > '9') {
      return false;
    }
  }
  return true;
}

/**
 * 解析时间戳文本。
 *
 * 支持负号（1970 年之前）与 10/13 位自动识别；位数或范围不合法时返回错误，
 * 不猜测用户意图——猜错一个时间戳比报一个错更难被发现。
 */
export function parseTimestamp(input: string): TimestampParseResult {
  const text: string = input.trim();
  if (text.length === 0) {
    return TimestampParseResult.failure(TimestampFailure.EMPTY, []);
  }
  let body: string = text;
  let negative: boolean = false;
  const first: string = text.charAt(0);
  if (first === '-') {
    negative = true;
    body = text.substring(1);
  } else if (first === '+') {
    body = text.substring(1);
  }
  if (!isAllDigits(body)) {
    return TimestampParseResult.failure(TimestampFailure.NOT_DIGITS, []);
  }
  if (body.length > TIMESTAMP_MAX_DIGITS) {
    return TimestampParseResult.failure(TimestampFailure.TOO_MANY_DIGITS,
      [String(TIMESTAMP_MAX_DIGITS)]);
  }
  const value: number = Number.parseInt(body, 10);
  const unit: TimestampUnit = body.length <= 10 ? TimestampUnit.SECONDS : TimestampUnit.MILLISECONDS;
  let milliseconds: number = unit === TimestampUnit.SECONDS ? value * 1000 : value;
  if (negative) {
    milliseconds = -milliseconds;
  }
  if (!isValidTimestamp(milliseconds)) {
    return TimestampParseResult.failure(TimestampFailure.OUT_OF_RANGE,
      [String(TIMESTAMP_MAX_MS)]);
  }
  return new TimestampParseResult(true, milliseconds, unit, body.length,
      TimestampFailure.NONE, []);
}

/** 取某时刻的墙上时间各部分；offsetMinutes 是相对 UTC 的分钟偏移（东八区 = 480） */
export function partsOf(ms: number, offsetMinutes: number): DateParts {
  const shifted: Date = new Date(ms + offsetMinutes * 60000);
  return new DateParts(
    shifted.getUTCFullYear(),
    shifted.getUTCMonth() + 1,
    shifted.getUTCDate(),
    shifted.getUTCHours(),
    shifted.getUTCMinutes(),
    shifted.getUTCSeconds(),
    shifted.getUTCMilliseconds(),
    shifted.getUTCDay()
  );
}

/** 星期中文名；越界返回空串而不是编一个值 */
export function weekdayLabel(weekday: number, locale: string): string {
  if (weekday < 0 || weekday > 6) {
    return '';
  }
  return WEEKDAY_LOCALIZED[weekday].forLocale(locale);
}

/**
 * 按模板格式化。
 *
 * 支持的记号：YYYY 年、MM 月、DD 日、HH 时、mm 分、ss 秒、SSS 毫秒，
 * 其余字符按字面输出。刻意只支持这几个：模板越灵活越容易和「用户以为的
 * 系统格式串（如 yyyy-MM-dd）混淆」，宁可少支持也不制造误解。
 */
export function formatParts(parts: DateParts, pattern: string): string {
  let out: string = '';
  let i: number = 0;
  while (i < pattern.length) {
    const rest: string = pattern.substring(i);
    if (rest.indexOf('YYYY') === 0) {
      out = out + padNumber(parts.year, 4);
      i = i + 4;
    } else if (rest.indexOf('SSS') === 0) {
      out = out + padNumber(parts.millisecond, 3);
      i = i + 3;
    } else if (rest.indexOf('MM') === 0) {
      out = out + padNumber(parts.month, 2);
      i = i + 2;
    } else if (rest.indexOf('DD') === 0) {
      out = out + padNumber(parts.day, 2);
      i = i + 2;
    } else if (rest.indexOf('HH') === 0) {
      out = out + padNumber(parts.hour, 2);
      i = i + 2;
    } else if (rest.indexOf('mm') === 0) {
      out = out + padNumber(parts.minute, 2);
      i = i + 2;
    } else if (rest.indexOf('ss') === 0) {
      out = out + padNumber(parts.second, 2);
      i = i + 2;
    } else {
      out = out + pattern.charAt(i);
      i++;
    }
  }
  return out;
}

/** 在指定偏移时区下格式化某个时刻 */
export function formatWithOffset(ms: number, offsetMinutes: number, pattern: string): string {
  return formatParts(partsOf(ms, offsetMinutes), pattern);
}

/** 本机时区在**该时刻**的偏移分钟数（东八区返回 480）。会跟随系统夏令时设置。 */
export function localOffsetMinutes(ms: number): number {
  return -new Date(ms).getTimezoneOffset();
}

/** 固定偏移的可读写法，例如 UTC+08:00 / UTC-05:30 / UTC+05:45 */
export function offsetText(offsetMinutes: number): string {
  const sign: string = offsetMinutes < 0 ? '-' : '+';
  const absolute: number = Math.abs(offsetMinutes);
  const hours: number = Math.floor(absolute / 60);
  const minutes: number = absolute - hours * 60;
  return 'UTC' + sign + padNumber(hours, 2) + ':' + padNumber(minutes, 2);
}

/**
 * 时区对照用的固定时区表。
 *
 * 全部按**冬季标准时间**固定：巴黎写成 UTC+1，夏天实际是 UTC+2，页面不跟随夏令时。
 * 本地时区单独用 {@link offsetOf} 取系统当前偏移。
 */
/** 简写构造器：把「中文 / English」写成一行 */
function l10n(zh: string, en: string): NGFLocalizedText {
  return new NGFLocalizedText(zh, en);
}

export function timeZoneOptions(): Array<TimeZoneOption> {
  const list: Array<TimeZoneOption> = [];
  list.push(new TimeZoneOption('local', l10n('本地时区', 'Local time zone'), 0, true));
  list.push(new TimeZoneOption('utc', l10n('UTC 协调世界时', 'UTC'), 0, false));
  list.push(new TimeZoneOption('beijing', l10n('北京 UTC+8', 'Beijing UTC+8'), 480, false));
  list.push(new TimeZoneOption('tokyo', l10n('东京 UTC+9', 'Tokyo UTC+9'), 540, false));
  list.push(new TimeZoneOption('delhi', l10n('新德里 UTC+5:30', 'New Delhi UTC+5:30'), 330, false));
  list.push(new TimeZoneOption('kathmandu', l10n('加德满都 UTC+5:45', 'Kathmandu UTC+5:45'), 345, false));
  list.push(new TimeZoneOption('moscow', l10n('莫斯科 UTC+3', 'Moscow UTC+3'), 180, false));
  list.push(new TimeZoneOption('paris', l10n('巴黎 UTC+1（冬季固定）', 'Paris UTC+1 (fixed, no DST)'), 60, false));
  list.push(new TimeZoneOption('london', l10n('伦敦 UTC+0（冬季固定）', 'London UTC+0 (fixed, no DST)'), 0, false));
  list.push(new TimeZoneOption('newyork', l10n('纽约 UTC-5（冬季固定）', 'New York UTC-5 (fixed, no DST)'), -300, false));
  list.push(new TimeZoneOption('losangeles', l10n('洛杉矶 UTC-8（冬季固定）', 'Los Angeles UTC-8 (fixed, no DST)'), -480, false));
  return list;
}

/** 取某个时区在指定时刻的偏移分钟数（本地时区走系统值） */
export function offsetOf(option: TimeZoneOption, ms: number): number {
  if (option.isLocal) {
    return localOffsetMinutes(ms);
  }
  return option.offsetMinutes;
}

/** 生成时区对照表的全部行 */
export function zoneRows(ms: number): Array<ZoneRow> {
  const options: Array<TimeZoneOption> = timeZoneOptions();
  const rows: Array<ZoneRow> = [];
  for (let i: number = 0; i < options.length; i++) {
    const option: TimeZoneOption = options[i];
    const offset: number = offsetOf(option, ms);
    const parts: DateParts = partsOf(ms, offset);
    rows.push(new ZoneRow(
      option.label,
      offsetText(offset),
      formatParts(parts, 'YYYY-MM-DD HH:mm:ss'),
      parts.weekday,
      option.isLocal
    ));
  }
  return rows;
}

/** 从字符串里读出一个非负整数；不是纯数字返回 -1 */
function readInt(text: string): number {
  if (!isAllDigits(text)) {
    return -1;
  }
  return Number.parseInt(text, 10);
}

/**
 * 解析日期字符串。
 *
 * 支持 YYYY-MM-DD / YYYY/MM/DD，可跟 HH:mm、HH:mm:ss、HH:mm:ss.SSS，
 * 日期与时间之间用空格或 T 分隔。**不接受**时区后缀（Z、+08:00）：
 * 那种输入的正确解释需要完整时区库，含糊接受会给出一个看起来对、其实错的时间。
 */
export function parseDateString(input: string, offsetMinutes: number): DateParseResult {
  const text: string = input.trim();
  if (text.length === 0) {
    return DateParseResult.failure(TimestampDateFailure.EMPTY, []);
  }
  const last: string = text.charAt(text.length - 1);
  if (last === 'Z' || last === 'z') {
    return DateParseResult.failure(TimestampDateFailure.ZONE_SUFFIX, []);
  }
  let separatorIndex: number = -1;
  for (let i: number = 0; i < text.length; i++) {
    const ch: string = text.charAt(i);
    if (ch === ' ' || ch === 'T' || ch === 't') {
      separatorIndex = i;
      break;
    }
  }
  const datePart: string = separatorIndex < 0 ? text : text.substring(0, separatorIndex);
  const timePart: string = separatorIndex < 0 ? '' : text.substring(separatorIndex + 1).trim();

  const dateGroups: Array<string> = datePart.indexOf('/') >= 0 ? datePart.split('/') : datePart.split('-');
  if (dateGroups.length !== 3) {
    return DateParseResult.failure(TimestampDateFailure.BAD_DATE_FORMAT, []);
  }
  const year: number = readInt(dateGroups[0]);
  const month: number = readInt(dateGroups[1]);
  const day: number = readInt(dateGroups[2]);
  if (year < 1 || month < 1 || day < 1) {
    return DateParseResult.failure(TimestampDateFailure.BAD_DATE_DIGITS, []);
  }
  if (year > 9999) {
    return DateParseResult.failure(TimestampDateFailure.YEAR_RANGE, []);
  }
  if (month > 12) {
    return DateParseResult.failure(TimestampDateFailure.MONTH_RANGE, []);
  }
  const maxDay: number = daysInMonth(year, month);
  if (day > maxDay) {
    return DateParseResult.failure(TimestampDateFailure.DAY_RANGE,
      [String(year), String(month), String(maxDay)]);
  }

  let hour: number = 0;
  let minute: number = 0;
  let second: number = 0;
  let millisecond: number = 0;
  if (timePart.length > 0) {
    const timeGroups: Array<string> = timePart.split(':');
    if (timeGroups.length < 2 || timeGroups.length > 3) {
      return DateParseResult.failure(TimestampDateFailure.BAD_TIME_FORMAT, []);
    }
    hour = readInt(timeGroups[0]);
    minute = readInt(timeGroups[1]);
    if (hour < 0 || minute < 0) {
      return DateParseResult.failure(TimestampDateFailure.BAD_TIME_FORMAT, []);
    }
    if (timeGroups.length === 3) {
      const secondGroup: string = timeGroups[2];
      const dotIndex: number = secondGroup.indexOf('.');
      if (dotIndex < 0) {
        second = readInt(secondGroup);
      } else {
        second = readInt(secondGroup.substring(0, dotIndex));
        const fraction: string = secondGroup.substring(dotIndex + 1);
        if (!isAllDigits(fraction) || fraction.length === 0) {
          return DateParseResult.failure(TimestampDateFailure.BAD_MILLIS, []);
        }
        // 只取前三位：JSON/ISO 里允许更精细的位数，但 Date 的精度就是毫秒
        let padded: string = fraction;
        while (padded.length < 3) {
          padded = padded + '0';
        }
        millisecond = Number.parseInt(padded.substring(0, 3), 10);
      }
    }
    if (second < 0) {
      return DateParseResult.failure(TimestampDateFailure.BAD_TIME_FORMAT, []);
    }
    if (hour > 23 || minute > 59 || second > 59) {
      return DateParseResult.failure(TimestampDateFailure.TIME_RANGE, []);
    }
  }

  // 先按 UTC 组装，再减去目标偏移：这样得到的是「该墙上时间在目标时区的绝对时刻」。
  // 用 setUTCFullYear 而不是 Date.UTC：Date.UTC 会把 0-99 的年份当成 1900+，
  // 而这里允许公元 1 年这类输入。
  const assembled: Date = new Date(0);
  assembled.setUTCFullYear(year, month - 1, day);
  assembled.setUTCHours(hour, minute, second, millisecond);
  const milliseconds: number = assembled.getTime() - offsetMinutes * 60000;
  if (!isValidTimestamp(milliseconds)) {
    return DateParseResult.failure(TimestampDateFailure.OUT_OF_RANGE, []);
  }
  return new DateParseResult(true, milliseconds, TimestampDateFailure.NONE, []);
}

/**
 * 相对时间描述。
 *
 * 为什么把 nowMs 作为参数而不是在函数里取 Date.now()：
 * 「3 分钟前」这种文案一旦依赖真实时钟就没法写稳定的单测，
 * 而且页面需要「以某个时刻为基准」展示，注入基准是唯一干净的做法。
 */
/** 相对时间的量级 */
export enum RelativeTimeUnit {
  /** 不到一分钟 */
  MOMENT = 'moment',
  MINUTES = 'minutes',
  HOURS = 'hours',
  DAYS = 'days',
  MONTHS = 'months',
  YEARS = 'years'
}

/**
 * 相对时间的**结构化**结果。
 *
 * 为什么不直接返回「1 分钟前」这种字符串：中英的**语序完全不同**——
 * 中文是「N 分钟前」（后缀），英文是 "N minutes ago"（也是后缀）或
 * "in N minutes"（未来时前缀 + 名词复数）。把数量与方向拆出来，
 * 每种语言才能自己决定怎么摆。
 */
export class RelativeTime {
  readonly unit: RelativeTimeUnit;
  /** 量级里的数量；MOMENT 时无意义 */
  readonly value: number;
  /** true = 过去，false = 未来 */
  readonly past: boolean;

  constructor(unit: RelativeTimeUnit, value: number, past: boolean) {
    this.unit = unit;
    this.value = value;
    this.past = past;
  }
}

export function relativeTime(targetMs: number, nowMs: number): RelativeTime {
  const diff: number = targetMs - nowMs;
  const past: boolean = diff <= 0;
  const abs: number = Math.abs(diff);
  if (abs < 60000) {
    return new RelativeTime(RelativeTimeUnit.MOMENT, 0, past);
  }
  const minutes: number = Math.floor(abs / 60000);
  if (minutes < 60) {
    return new RelativeTime(RelativeTimeUnit.MINUTES, minutes, past);
  }
  const hours: number = Math.floor(abs / 3600000);
  if (hours < 24) {
    return new RelativeTime(RelativeTimeUnit.HOURS, hours, past);
  }
  const days: number = Math.floor(abs / 86400000);
  if (days < 30) {
    return new RelativeTime(RelativeTimeUnit.DAYS, days, past);
  }
  // 一年以内一律按月说：364 天就是「12 个月前」。说成「1 年前」是四舍五入，
  // 用户对着日历一减就能发现少了一天。反过来也顺手消掉了
  // 「360-364 天按年算得 0 年」这个尴尬区间。
  if (days < 365) {
    return new RelativeTime(RelativeTimeUnit.MONTHS, Math.floor(days / 30), past);
  }
  return new RelativeTime(RelativeTimeUnit.YEARS, Math.floor(days / 365), past);
}

/**
 * 把一段输入**双向**解释：能当时间戳当时间戳，否则当日期字符串。
 *
 * 页面只有一个输入框（时间戳与日期共用），判定逻辑必须收口在这里，
 * 否则「什么时候当时间戳」会散落在 UI 里，两边口径迟早不一致。
 *
 * @param offsetMinutes 展示用的时区偏移（页面传本机偏移即显示本地时间）
 */
export function interpretInput(input: string, offsetMinutes: number): TimestampInterpretation {
  const text: string = input.trim();
  if (text.length === 0) {
    return new TimestampInterpretation(InterpretKind.EMPTY, 0, TimestampUnit.SECONDS,
      '', '', '', '', InterpretFailure.none());
  }
  let body: string = text;
  if (text.charAt(0) === '-' || text.charAt(0) === '+') {
    body = text.substring(1);
  }
  if (isAllDigits(body)) {
    const parsed: TimestampParseResult = parseTimestamp(text);
    if (!parsed.ok) {
      return new TimestampInterpretation(InterpretKind.INVALID, 0, parsed.unit, '', '', '', '',
        InterpretFailure.ofTimestamp(parsed));
    }
    return describeMoment(InterpretKind.TIMESTAMP, parsed.milliseconds, parsed.unit, offsetMinutes);
  }
  const dateResult: DateParseResult = parseDateString(text, offsetMinutes);
  if (!dateResult.ok) {
    return new TimestampInterpretation(InterpretKind.INVALID, 0, TimestampUnit.MILLISECONDS,
      '', '', '', '', InterpretFailure.ofDate(dateResult));
  }
  return describeMoment(InterpretKind.DATE, dateResult.milliseconds, TimestampUnit.MILLISECONDS, offsetMinutes);
}

/** 把一个时刻摊成页面需要的几种写法 */
function describeMoment(kind: InterpretKind, ms: number, unit: TimestampUnit,
                        offsetMinutes: number): TimestampInterpretation {
  return new TimestampInterpretation(
    kind,
    ms,
    unit,
    String(millisToSeconds(ms)),
    String(ms),
    formatWithOffset(ms, offsetMinutes, 'YYYY-MM-DD HH:mm:ss'),
    formatWithOffset(ms, 0, 'YYYY-MM-DD HH:mm:ss'),
    InterpretFailure.none()
  );
}