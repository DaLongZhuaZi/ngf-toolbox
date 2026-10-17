/**
 * 正则测试工具的显示文案（**UI 层**，可以 import ArkUI）。
 *
 * 纯逻辑只给：引擎错误的种类、预检问题的种类、标志码、摘要计数、以及预设/速查表的双语数据。
 * 措辞全在这里。
 *
 * 有一处刻意的例外：**可复制的文本报告**留在纯逻辑里（buildMatchReport），
 * 因为它的格式（一条匹配一行、换行转义）是容易被真机噪声掩盖的缺陷，必须由单测守住。
 * 所以报告把「摘要句」和「错误句」作为参数接收——格式一份，句子两套。
 *
 * @module tools/regex-tester/RegexMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { NGFLocalizedText } from '../../core/ToolModel';
import {
  RegexCheatSheetItem,
  RegexErrorKind,
  RegexFlag,
  RegexIssueKind,
  RegexMatch,
  RegexPreset,
  RegexSummary
} from './RegexLogic';

/** 引擎错误翻译成人话 */
export function regexErrorKindText(kind: RegexErrorKind): string {
  if (kind === RegexErrorKind.UNTERMINATED_GROUP) {
    return ToolUiKit.text($r('app.string.regex_err_unterminated_group'));
  }
  if (kind === RegexErrorKind.UNMATCHED_CLOSE) {
    return ToolUiKit.text($r('app.string.regex_err_unmatched_close'));
  }
  if (kind === RegexErrorKind.UNTERMINATED_CLASS) {
    return ToolUiKit.text($r('app.string.regex_err_unterminated_class'));
  }
  if (kind === RegexErrorKind.NOTHING_TO_REPEAT) {
    return ToolUiKit.text($r('app.string.regex_err_nothing_to_repeat'));
  }
  if (kind === RegexErrorKind.RANGE_OUT_OF_ORDER) {
    return ToolUiKit.text($r('app.string.regex_err_range_out_of_order'));
  }
  if (kind === RegexErrorKind.INCOMPLETE_QUANTIFIER) {
    return ToolUiKit.text($r('app.string.regex_err_incomplete_quantifier'));
  }
  if (kind === RegexErrorKind.INVALID_GROUP) {
    return ToolUiKit.text($r('app.string.regex_err_invalid_group'));
  }
  if (kind === RegexErrorKind.INVALID_UNICODE_ESCAPE) {
    return ToolUiKit.text($r('app.string.regex_err_invalid_unicode_escape'));
  }
  if (kind === RegexErrorKind.INVALID_ESCAPE) {
    return ToolUiKit.text($r('app.string.regex_err_invalid_escape'));
  }
  if (kind === RegexErrorKind.INVALID_CHAR_CLASS) {
    return ToolUiKit.text($r('app.string.regex_err_invalid_char_class'));
  }
  if (kind === RegexErrorKind.INVALID_PROPERTY) {
    return ToolUiKit.text($r('app.string.regex_err_invalid_property'));
  }
  if (kind === RegexErrorKind.SYNTAX) {
    return ToolUiKit.text($r('app.string.regex_err_syntax'));
  }
  return ToolUiKit.text($r('app.string.regex_err_parse_error'));
}

/** 预检问题 */
export function regexIssueText(kind: RegexIssueKind, args: Array<string>): string {
  if (kind === RegexIssueKind.TRAILING_BACKSLASH) {
    return ToolUiKit.text($r('app.string.regex_issue_trailing_backslash'));
  }
  if (kind === RegexIssueKind.UNMATCHED_CLOSE) {
    return ToolUiKit.text($r('app.string.regex_issue_unmatched_close'));
  }
  if (kind === RegexIssueKind.NOTHING_TO_REPEAT) {
    return ToolUiKit.text($r('app.string.regex_issue_nothing_to_repeat'));
  }
  if (kind === RegexIssueKind.NOTHING_TO_REPEAT_QUESTION) {
    return ToolUiKit.text($r('app.string.regex_issue_nothing_to_repeat_question'));
  }
  if (kind === RegexIssueKind.UNTERMINATED_CLASS) {
    return ToolUiKit.text($r('app.string.regex_issue_unterminated_class'));
  }
  if (kind === RegexIssueKind.UNTERMINATED_GROUP) {
    return ToolUiKit.text($r('app.string.regex_issue_unterminated_group'));
  }
  return ToolUiKit.stringOf($r('app.string.regex_issue_range_reversed'), [args[0], args[1]]);
}

/**
 * 编译失败的完整提示：句子 + 位置。
 *
 * 位置同样不拼进句子里——中文写「（第 3 个字符附近）」，英文写 " (near character 3)"。
 * 位置取不到时（-1）**不补一个假位置**，直接只给句子。
 */
export function regexBuildErrorText(kind: RegexErrorKind, position: number): string {
  const reason: string = regexErrorKindText(kind);
  if (position < 0) {
    return reason;
  }
  return reason + ToolUiKit.stringOf($r('app.string.regex_error_near'),
    [String(position + 1)]);
}

/** 单个标志的名字（'g 全局'） */
export function regexFlagText(flag: RegexFlag): string {
  if (flag === RegexFlag.GLOBAL) {
    return ToolUiKit.text($r('app.string.regex_flag_global'));
  }
  if (flag === RegexFlag.IGNORE_CASE) {
    return ToolUiKit.text($r('app.string.regex_flag_ignore_case'));
  }
  if (flag === RegexFlag.MULTILINE) {
    return ToolUiKit.text($r('app.string.regex_flag_multiline'));
  }
  if (flag === RegexFlag.DOT_ALL) {
    return ToolUiKit.text($r('app.string.regex_flag_dot_all'));
  }
  return ToolUiKit.text($r('app.string.regex_flag_unicode'));
}

/** 单个标志的作用说明 */
export function regexFlagHintText(flag: RegexFlag): string {
  if (flag === RegexFlag.GLOBAL) {
    return ToolUiKit.text($r('app.string.regex_flag_global_hint'));
  }
  if (flag === RegexFlag.IGNORE_CASE) {
    return ToolUiKit.text($r('app.string.regex_flag_ignore_case_hint'));
  }
  if (flag === RegexFlag.MULTILINE) {
    return ToolUiKit.text($r('app.string.regex_flag_multiline_hint'));
  }
  if (flag === RegexFlag.DOT_ALL) {
    return ToolUiKit.text($r('app.string.regex_flag_dot_all_hint'));
  }
  return ToolUiKit.text($r('app.string.regex_flag_unicode_hint'));
}

/** 已开标志连成一句（'全局、忽略大小写'）；一个都没开时给「无标志」 */
export function regexFlagsText(flags: Array<RegexFlag>): string {
  if (flags.length === 0) {
    return ToolUiKit.text($r('app.string.regex_flag_none'));
  }
  let text: string = '';
  for (let i: number = 0; i < flags.length; i++) {
    if (i > 0) {
      text += ToolUiKit.text($r('app.string.regex_list_separator'));
    }
    text += regexFlagText(flags[i]);
  }
  return text;
}

/** 结果摘要 */
export function regexSummaryText(summary: RegexSummary): string {
  if (!summary.ok) {
    return ToolUiKit.text($r('app.string.regex_summary_failed'));
  }
  if (summary.empty) {
    return ToolUiKit.stringOf($r('app.string.regex_summary_no_match'),
      [String(summary.textLength)]);
  }
  let text: string = ToolUiKit.stringOf($r('app.string.regex_summary_matched'),
    [String(summary.matchCount)]);
  if (summary.truncated) {
    text += ToolUiKit.stringOf($r('app.string.regex_summary_truncated'),
      [String(summary.limit), String(summary.matchCount)]);
  }
  if (summary.zeroWidth > 0) {
    text += ToolUiKit.stringOf($r('app.string.regex_summary_zero_width'),
      [String(summary.zeroWidth)]);
  }
  return text;
}

/** 预设名 / 说明 / 速查表含义 —— 都是双语数据 */
export function regexPresetName(preset: RegexPreset, locale: string): string {
  return preset.name.forLocale(locale);
}

export function regexPresetHint(preset: RegexPreset, locale: string): string {
  return preset.hint.forLocale(locale);
}

export function regexCheatMeaning(item: RegexCheatSheetItem, locale: string): string {
  return item.meaning.forLocale(locale);
}

/** 一条匹配覆盖的字符范围；零宽要单独说明，否则用户会以为界面坏了 */
export function regexMatchRangeText(match: RegexMatch): string {
  if (match.isZeroWidth()) {
    return ToolUiKit.stringOf($r('app.string.regex_match_zero_width'),
      [String(match.start + 1)]);
  }
  return ToolUiKit.stringOf($r('app.string.regex_match_range'),
    [String(match.start + 1), String(match.end)]);
}

/** 一条捕获组的展示（'分组 1 = abc'） */
export function regexCaptureText(name: string, value: string): string {
  const shown: string = value.length > 0
    ? value
    : ToolUiKit.text($r('app.string.regex_capture_unmatched'));
  return ToolUiKit.stringOf($r('app.string.regex_capture_line'), [name, shown]);
}
