/**
 * 日期计算的显示文案（**UI 层**，可以 import ArkUI）。
 *
 * ## 这一层的三件事
 *
 * 1. 解析失败翻译成人话（`DateParseFailure` → 文案）；
 * 2. 间隔/加减的失败**带上下文**：失败其实是「某一侧日期解析不了」，
 *    所以要拼成「起始日期：月份必须在 1-12 之间」这种形式；
 * 3. 结果的叙述句（「相差 N 天；其中 M 天是工作日」）。
 *
 * 第 2、3 点都会**拼接句子**，这里可以，是因为拼的都是**完整句子**（各自带句号），
 * 而不是把词嵌进句子中间——后者才是 i18n 的坑（见 digest 的注释）。
 *
 * @module tools/date-calc/DateCalcMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import {
  DateDiffField,
  DateDiffResult,
  DateParseFailure,
  DateShiftFailure,
  DateShiftResult
} from './DateCalc';

/** 日期解析失败翻译成人话 */
export function dateParseFailureText(failure: DateParseFailure, args: Array<string>): string {
  if (failure === DateParseFailure.EMPTY) {
    return ToolUiKit.text($r('app.string.date_err_empty'));
  }
  if (failure === DateParseFailure.UNRECOGNIZED) {
    // ⚠️ 这里原来用的是 ToolUiKit.text()，而资源串带着 %s 占位符——
    // 结果真机上直接显示出一个字面的「无法识别的日期格式：%s」。
    // 带参数的资源必须走 stringOf（同文件其它分支都是这么写的）。
    return ToolUiKit.stringOf($r('app.string.date_err_unrecognized'), [args[0]]);
  }
  if (failure === DateParseFailure.NON_DIGIT) {
    return ToolUiKit.stringOf($r('app.string.date_err_non_digit'), [args[0]]);
  }
  if (failure === DateParseFailure.YEAR_RANGE) {
    return ToolUiKit.stringOf($r('app.string.date_err_year_range'), [args[0], args[1]]);
  }
  if (failure === DateParseFailure.MONTH_RANGE) {
    return ToolUiKit.text($r('app.string.date_err_month_range'));
  }
  if (failure === DateParseFailure.DAY_RANGE) {
    return ToolUiKit.stringOf($r('app.string.date_err_day_range'),
      [args[0], args[1], args[2], args[3]]);
  }
  return '';
}

/** 间隔计算的失败：外层是「哪一侧」，内层是那一侧为什么解析不了 */
export function dateDiffFailureText(result: DateDiffResult): string {
  const inner: string = dateParseFailureText(result.failure.innerFailure, result.failure.innerArgs);
  if (result.failure.field === DateDiffField.START) {
    return ToolUiKit.stringOf($r('app.string.date_err_diff_start'), [inner]);
  }
  return ToolUiKit.stringOf($r('app.string.date_err_diff_end'), [inner]);
}

/** 日期加减的失败 */
export function dateShiftFailureText(result: DateShiftResult): string {
  const failure: DateShiftFailure = result.failure;
  if (failure === DateShiftFailure.DAYS_NOT_INTEGER) {
    return ToolUiKit.text($r('app.string.date_err_days_not_integer'));
  }
  if (failure === DateShiftFailure.MONTHS_NOT_INTEGER) {
    return ToolUiKit.text($r('app.string.date_err_months_not_integer'));
  }
  if (failure === DateShiftFailure.YEARS_NOT_INTEGER) {
    return ToolUiKit.text($r('app.string.date_err_years_not_integer'));
  }
  if (failure === DateShiftFailure.OUT_OF_RANGE) {
    return ToolUiKit.stringOf($r('app.string.date_err_out_of_range'),
      [result.args[0], result.args[1]]);
  }
  if (failure === DateShiftFailure.BAD_BASE_DATE) {
    // 基准日期解析不了：直接转述内层原因（不必再套「基准日期：」，
    // 因为页面上这块只有一个输入框，用户不会搞错是哪个）
    return dateParseFailureText(result.innerFailure, result.innerArgs);
  }
  return '';
}

/**
 * 间隔结果的叙述句。
 *
 * 拆成两句再拼，而不是写成一个带四个 %s 的长句：中文的顺序是
 * 「相差 N 天；其中 M 天是工作日」，英文是「A difference of N days. M of them are working days.」，
 * 两边的占位符**顺序不一样**。写成两句各自独立，谁都不用迁就谁。
 */
export function dateGapText(result: DateDiffResult, excludeWeekends: boolean): string {
  const head: string = ToolUiKit.stringOf($r('app.string.date_gap_days'),
    [String(result.days)]);
  const unit: string = excludeWeekends
    ? ToolUiKit.text($r('app.string.date_unit_workday'))
    : ToolUiKit.text($r('app.string.date_unit_calendar'));
  const body: string = ToolUiKit.stringOf($r('app.string.date_gap_workdays'),
    [String(result.workdays), unit]);
  const direction: string = result.reversed
    ? ToolUiKit.text($r('app.string.date_notice_reversed'))
    : '';
  return head + body + direction;
}
