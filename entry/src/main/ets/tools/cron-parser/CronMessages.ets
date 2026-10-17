/**
 * cron 解析的显示文案（**UI 层**，可以 import ArkUI）。
 *
 * 纯逻辑只给结构与数字：失败码、段标识、以及「按哪种基准 + 哪些数字」的描述结构。
 * 措辞全在这里。
 *
 * 最典型的例子是描述句：中文说「每 5 分钟（9、17 点内）」，
 * 英文是 "Every 5 minutes (during hours 9 and 17)"——量词、连接词、括号位置全不同。
 * 所以纯逻辑给的是 (基准, 步长, 小时数组, 分钟数组, 限定标志)，怎么摆归这一层。
 *
 * @module tools/cron-parser/CronMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import {
  CronDescription,
  CronFieldError,
  CronFieldKey,
  CronParseFailure,
  CronParseFailureCode,
  CronTimeBasis
} from './CronParser';

/** 段名（「分钟」/「小时」…），供「%s段为空」这类句子使用 */
export function cronFieldNameText(key: CronFieldKey): string {
  if (key === CronFieldKey.HOUR) {
    return ToolUiKit.text($r('app.string.cron_field_hour'));
  }
  if (key === CronFieldKey.DAY_OF_MONTH) {
    return ToolUiKit.text($r('app.string.cron_field_day'));
  }
  if (key === CronFieldKey.MONTH) {
    return ToolUiKit.text($r('app.string.cron_field_month'));
  }
  if (key === CronFieldKey.DAY_OF_WEEK) {
    return ToolUiKit.text($r('app.string.cron_field_weekday'));
  }
  return ToolUiKit.text($r('app.string.cron_field_minute'));
}

/** 段内失败翻译成人话（段名作为第一个参数传进去） */
function fieldErrorText(error: CronFieldError, key: CronFieldKey,
  args: Array<string>): string {
  const name: string = cronFieldNameText(key);
  if (error === CronFieldError.EMPTY) {
    return ToolUiKit.stringOf($r('app.string.cron_err_field_empty'), [name]);
  }
  if (error === CronFieldError.BAD_STEP) {
    return ToolUiKit.stringOf($r('app.string.cron_err_bad_step'), [name, args[0]]);
  }
  if (error === CronFieldError.STEP_NOT_POSITIVE) {
    return ToolUiKit.stringOf($r('app.string.cron_err_step_not_positive'), [name, args[0]]);
  }
  if (error === CronFieldError.EMPTY_ITEM) {
    return ToolUiKit.stringOf($r('app.string.cron_err_empty_item'), [name]);
  }
  if (error === CronFieldError.RANGE_SYNTAX) {
    return ToolUiKit.stringOf($r('app.string.cron_err_range_syntax'), [name, args[0]]);
  }
  if (error === CronFieldError.OUT_OF_RANGE) {
    return ToolUiKit.stringOf($r('app.string.cron_err_out_of_range'),
      [name, args[0], args[1], args[2]]);
  }
  if (error === CronFieldError.REVERSED_RANGE) {
    return ToolUiKit.stringOf($r('app.string.cron_err_reversed_range'), [name, args[0]]);
  }
  if (error === CronFieldError.BAD_VALUE) {
    return ToolUiKit.stringOf($r('app.string.cron_err_bad_value'), [name, args[0]]);
  }
  return ToolUiKit.stringOf($r('app.string.cron_err_no_values'), [name, args[0]]);
}

/**
 * 顶层失败翻译成人话。
 *
 * 段数不对时可能要说三句（基础 + 6 段 + 别名），纯逻辑把它们列成码数组，
 * 这里逐句翻译再拼。**每句各自是完整句子**，所以拼接是安全的。
 */
export function cronFailureText(failure: CronParseFailure): string {
  let text: string = '';
  for (let i: number = 0; i < failure.codes.length; i++) {
    const code: CronParseFailureCode = failure.codes[i];
    if (code === CronParseFailureCode.EMPTY) {
      text += ToolUiKit.text($r('app.string.cron_err_empty_expression'));
    } else if (code === CronParseFailureCode.WRONG_SEGMENT_COUNT) {
      text += ToolUiKit.stringOf($r('app.string.cron_err_wrong_count'), [failure.args[0]]);
    } else if (code === CronParseFailureCode.SIX_SEGMENTS) {
      text += ToolUiKit.text($r('app.string.cron_err_six_segments'));
    } else if (code === CronParseFailureCode.ALIAS) {
      text += ToolUiKit.text($r('app.string.cron_err_alias'));
    } else if (code === CronParseFailureCode.FIELD) {
      text += fieldErrorText(failure.fieldCode, failure.fieldKey, failure.fieldArgs);
    }
  }
  return text;
}

/** 星期名（0=周日） */
export function cronWeekdayText(index: number): string {
  const keys: Array<Resource> = [
    $r('app.string.cron_weekday_sun'), $r('app.string.cron_weekday_mon'),
    $r('app.string.cron_weekday_tue'), $r('app.string.cron_weekday_wed'),
    $r('app.string.cron_weekday_thu'), $r('app.string.cron_weekday_fri'),
    $r('app.string.cron_weekday_sat')
  ];
  if (index < 0 || index > 6) {
    return '';
  }
  return ToolUiKit.text(keys[index]);
}

/** 月份名（1-12） */
export function cronMonthText(value: number): string {
  const keys: Array<Resource> = [
    $r('app.string.cron_month_1'), $r('app.string.cron_month_2'),
    $r('app.string.cron_month_3'), $r('app.string.cron_month_4'),
    $r('app.string.cron_month_5'), $r('app.string.cron_month_6'),
    $r('app.string.cron_month_7'), $r('app.string.cron_month_8'),
    $r('app.string.cron_month_9'), $r('app.string.cron_month_10'),
    $r('app.string.cron_month_11'), $r('app.string.cron_month_12')
  ];
  if (value < 1 || value > 12) {
    return '';
  }
  return ToolUiKit.text(keys[value - 1]);
}

/** 数值列表（用本语言的顿号/逗号连接） */
function numberList(values: Array<number>, pad: boolean): string {
  let text: string = '';
  for (let i: number = 0; i < values.length; i++) {
    if (i > 0) {
      text += ToolUiKit.text($r('app.string.cron_list_separator'));
    }
    const value: number = values[i];
    text += pad && value < 10 ? '0' + String(value) : String(value);
  }
  return text;
}

/** 时刻列表（'03:00、09:30'） */
function timeList(hours: Array<number>, minutes: Array<number>): string {
  let text: string = '';
  for (let i: number = 0; i < hours.length; i++) {
    for (let j: number = 0; j < minutes.length; j++) {
      if (text.length > 0) {
        text += ToolUiKit.text($r('app.string.cron_list_separator'));
      }
      const hour: number = hours[i];
      const minute: number = minutes[j];
      text += (hour < 10 ? '0' + String(hour) : String(hour)) + ':'
        + (minute < 10 ? '0' + String(minute) : String(minute));
    }
  }
  return text;
}

/** 小时列表带单位（'9、17 点' / 'hours 9, 17'） */
function hourList(values: Array<number>): string {
  return ToolUiKit.stringOf($r('app.string.cron_hours'),
    [numberList(values, true)]);
}

/**
 * 人话描述：按基准选句式，再把限定条件拼成括号里的补充。
 *
 * 「括号 + 或/且 连接」这套结构在中英之间是一致的，所以这里可以整体拼；
 * 但**每一段都是完整的词组**，不是把词嵌进句子中间。
 */
export function cronDescriptionText(desc: CronDescription): string {
  let timePart: string = '';
  if (desc.basis === CronTimeBasis.EVERY_MINUTE) {
    timePart = desc.hoursRestricted
      ? ToolUiKit.stringOf($r('app.string.cron_desc_every_minute_at_hours'),
        [hourList(desc.hours)])
      : ToolUiKit.text($r('app.string.cron_desc_every_minute'));
  } else if (desc.basis === CronTimeBasis.EVERY_N_MINUTES) {
    timePart = ToolUiKit.stringOf($r('app.string.cron_desc_every_n_minutes'),
      [String(desc.step)]);
    if (desc.hoursRestricted) {
      timePart += ToolUiKit.stringOf($r('app.string.cron_desc_within_hours'),
        [hourList(desc.hours)]);
    }
  } else if (desc.basis === CronTimeBasis.AT_MINUTE_OF_EVERY_HOUR) {
    timePart = ToolUiKit.stringOf($r('app.string.cron_desc_at_minute_of_hour'),
      [numberList(desc.minutes, true)]);
  } else if (desc.basis === CronTimeBasis.AT_TIMES) {
    timePart = ToolUiKit.stringOf($r('app.string.cron_desc_at_times'),
      [timeList(desc.hours, desc.minutes)]);
  }

  const qualifiers: Array<string> = [];
  if (desc.monthsRestricted) {
    let monthText: string = '';
    for (let i: number = 0; i < desc.months.length; i++) {
      if (i > 0) {
        monthText += ToolUiKit.text($r('app.string.cron_list_separator'));
      }
      monthText += cronMonthText(desc.months[i]);
    }
    qualifiers.push(ToolUiKit.stringOf($r('app.string.cron_desc_year'), [monthText]));
  }
  if (desc.daysOfMonthRestricted) {
    qualifiers.push(ToolUiKit.stringOf($r('app.string.cron_desc_month_day'),
      [numberList(desc.daysOfMonth, false)]));
  }
  if (desc.daysOfWeekRestricted) {
    let weekdayText: string = '';
    for (let i: number = 0; i < desc.daysOfWeek.length; i++) {
      if (i > 0) {
        weekdayText += ToolUiKit.text($r('app.string.cron_list_separator'));
      }
      weekdayText += cronWeekdayText(desc.daysOfWeek[i]);
    }
    qualifiers.push(ToolUiKit.stringOf($r('app.string.cron_desc_week'), [weekdayText]));
  }

  if (qualifiers.length === 0) {
    return timePart + ToolUiKit.text($r('app.string.cron_desc_daily_suffix'));
  }
  const joiner: string = desc.dayFieldsAreOr
    ? ToolUiKit.text($r('app.string.cron_desc_or'))
    : ToolUiKit.text($r('app.string.cron_desc_and'));
  let joined: string = '';
  for (let i: number = 0; i < qualifiers.length; i++) {
    if (i > 0) {
      joined += joiner;
    }
    joined += qualifiers[i];
  }
  return timePart + ToolUiKit.stringOf($r('app.string.cron_desc_wrap'), [joined]);
}
