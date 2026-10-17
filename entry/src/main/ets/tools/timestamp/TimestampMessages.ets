/**
 * 时间戳工具的显示文案（**UI 层**，可以 import ArkUI）。
 *
 * 纯逻辑（\`TimestampLogic.ets\`）只给：失败原因码、时区双语名、星期的双语名，
 * 以及**结构化**的相对时间。措辞全在这里。
 *
 * 相对时间是这一层存在的最好例子：中文说「3 分钟前」，英文说 "in 3 minutes"（未来）
 * 或 "3 minutes ago"（过去）——**词序与介词完全不同**。纯逻辑只给
 * 「量级 + 数量 + 方向」，怎么摆是每种语言自己的事。
 *
 * @module tools/timestamp/TimestampMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { NGFLocalizedText } from '../../core/ToolModel';
import {
  InterpretFailure,
  RelativeTime,
  RelativeTimeUnit,
  TimestampDateFailure,
  TimestampFailure,
  TimeZoneOption,
  ZoneRow
} from './TimestampLogic';

/** 时间戳解析失败翻译成人话 */
export function timestampFailureText(failure: TimestampFailure, args: Array<string>): string {
  if (failure === TimestampFailure.EMPTY) {
    return ToolUiKit.text($r('app.string.ts_err_empty'));
  }
  if (failure === TimestampFailure.NOT_DIGITS) {
    return ToolUiKit.text($r('app.string.ts_err_not_digits'));
  }
  if (failure === TimestampFailure.TOO_MANY_DIGITS) {
    return ToolUiKit.stringOf($r('app.string.ts_err_too_many_digits'), [args[0]]);
  }
  if (failure === TimestampFailure.OUT_OF_RANGE) {
    return ToolUiKit.stringOf($r('app.string.ts_err_ts_out_of_range'), [args[0]]);
  }
  return '';
}

/** 日期/时间解析失败翻译成人话 */
export function dateFailureText(failure: TimestampDateFailure, args: Array<string>): string {
  if (failure === TimestampDateFailure.EMPTY) {
    return ToolUiKit.text($r('app.string.ts_err_date_empty'));
  }
  if (failure === TimestampDateFailure.ZONE_SUFFIX) {
    return ToolUiKit.text($r('app.string.ts_err_zone_suffix'));
  }
  if (failure === TimestampDateFailure.BAD_DATE_FORMAT) {
    return ToolUiKit.text($r('app.string.ts_err_bad_date_format'));
  }
  if (failure === TimestampDateFailure.BAD_DATE_DIGITS) {
    return ToolUiKit.text($r('app.string.ts_err_bad_date_digits'));
  }
  if (failure === TimestampDateFailure.YEAR_RANGE) {
    return ToolUiKit.text($r('app.string.ts_err_year_range'));
  }
  if (failure === TimestampDateFailure.MONTH_RANGE) {
    return ToolUiKit.text($r('app.string.ts_err_month_range'));
  }
  if (failure === TimestampDateFailure.DAY_RANGE) {
    return ToolUiKit.stringOf($r('app.string.ts_err_day_range'), [args[0], args[1], args[2]]);
  }
  if (failure === TimestampDateFailure.BAD_TIME_FORMAT) {
    return ToolUiKit.text($r('app.string.ts_err_bad_time_format'));
  }
  if (failure === TimestampDateFailure.BAD_MILLIS) {
    return ToolUiKit.text($r('app.string.ts_err_bad_millis'));
  }
  if (failure === TimestampDateFailure.TIME_RANGE) {
    return ToolUiKit.text($r('app.string.ts_err_time_range'));
  }
  if (failure === TimestampDateFailure.OUT_OF_RANGE) {
    return ToolUiKit.text($r('app.string.ts_err_date_out_of_range'));
  }
  return '';
}

/** 「双向解释」的失败：转述下游原因 */
export function interpretFailureText(failure: InterpretFailure): string {
  if (failure.fromTimestamp) {
    return timestampFailureText(failure.timestampFailure, failure.args);
  }
  return dateFailureText(failure.dateFailure, failure.args);
}

/** 相对时间的措辞。词序因语言而异，所以按「量级 + 方向」分支，各自是一个整句资源。 */
export function relativeTimeText(time: RelativeTime): string {
  const value: string = String(time.value);
  if (time.unit === RelativeTimeUnit.MOMENT) {
    return time.past
      ? ToolUiKit.text($r('app.string.ts_rel_just_now'))
      : ToolUiKit.text($r('app.string.ts_rel_imminent'));
  }
  if (time.unit === RelativeTimeUnit.MINUTES) {
    return time.past
      ? ToolUiKit.stringOf($r('app.string.ts_rel_minutes_ago'), [value])
      : ToolUiKit.stringOf($r('app.string.ts_rel_minutes_later'), [value]);
  }
  if (time.unit === RelativeTimeUnit.HOURS) {
    return time.past
      ? ToolUiKit.stringOf($r('app.string.ts_rel_hours_ago'), [value])
      : ToolUiKit.stringOf($r('app.string.ts_rel_hours_later'), [value]);
  }
  if (time.unit === RelativeTimeUnit.DAYS) {
    return time.past
      ? ToolUiKit.stringOf($r('app.string.ts_rel_days_ago'), [value])
      : ToolUiKit.stringOf($r('app.string.ts_rel_days_later'), [value]);
  }
  if (time.unit === RelativeTimeUnit.MONTHS) {
    return time.past
      ? ToolUiKit.stringOf($r('app.string.ts_rel_months_ago'), [value])
      : ToolUiKit.stringOf($r('app.string.ts_rel_months_later'), [value]);
  }
  return time.past
    ? ToolUiKit.stringOf($r('app.string.ts_rel_years_ago'), [value])
    : ToolUiKit.stringOf($r('app.string.ts_rel_years_later'), [value]);
}

/** 时区名（双语数据按 locale 取） */
export function zoneLabel(label: NGFLocalizedText, locale: string): string {
  return label.forLocale(locale);
}

/** 时区对照表某一行的星期（双语数据按 locale 取） */
export function zoneWeekdayText(row: ZoneRow, locale: string): string {
  return weekdayText(row.weekdayIndex, locale);
}

/** 星期几的展示名（越界返回空串） */
export function weekdayText(weekday: number, locale: string): string {
  if (weekday < 0 || weekday > 6) {
    return '';
  }
  return WEEKDAYS[weekday].forLocale(locale);
}

/** 与纯逻辑里的表对应；放在这一层是因为它要按 locale 取 */
const WEEKDAYS: NGFLocalizedText[] = [
  new NGFLocalizedText('周日', 'Sun'),
  new NGFLocalizedText('周一', 'Mon'),
  new NGFLocalizedText('周二', 'Tue'),
  new NGFLocalizedText('周三', 'Wed'),
  new NGFLocalizedText('周四', 'Thu'),
  new NGFLocalizedText('周五', 'Fri'),
  new NGFLocalizedText('周六', 'Sat')
];

/** 时区下拉的选项名 */
export function zoneOptionLabel(option: TimeZoneOption, locale: string): string {
  return option.label.forLocale(locale);
}

/** 解释方式的说明（页面顶部那句「按秒级时间戳解释」） */
export function interpretKindText(kind: string, isSeconds: boolean): string {
  if (kind === 'date') {
    return ToolUiKit.text($r('app.string.ts_interpret_date'));
  }
  return isSeconds
    ? ToolUiKit.text($r('app.string.ts_interpret_seconds'))
    : ToolUiKit.text($r('app.string.ts_interpret_millis'));
}
