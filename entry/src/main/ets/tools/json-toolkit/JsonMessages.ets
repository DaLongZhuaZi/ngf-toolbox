/**
 * JSON 工具箱的显示文案（**UI 层**，可以 import ArkUI）。
 *
 * 纯逻辑只给失败码 + 参数 + 位置，措辞全在这里。
 *
 * 位置尤其不能拼进句子里：中文写「第 3 行第 5 列」，英文写 "line 3, column 5"，
 * 连标点都不同。所以这边先按资源拼出位置，再把「错误 + （位置）」整体包一层——
 * **两层都是整句资源**，不是把词嵌进句子中间。
 *
 * @module tools/json-toolkit/JsonMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { JsonError, JsonErrorCode, JsonNodeKind, JsonSummary } from './JsonLogic';

/** 「第 3 行第 5 列」/ "line 3, column 5" */
export function jsonPositionText(error: JsonError): string {
  return ToolUiKit.stringOf($r('app.string.json_error_at'),
    [String(error.line), String(error.column)]);
}

/** 错误正文（不含位置） */
export function jsonReasonText(code: JsonErrorCode, args: Array<string>): string {
  if (code === JsonErrorCode.EMPTY) {
    return ToolUiKit.text($r('app.string.json_err_empty'));
  }
  if (code === JsonErrorCode.TRAILING) {
    return ToolUiKit.text($r('app.string.json_err_trailing'));
  }
  if (code === JsonErrorCode.NOTHING) {
    return ToolUiKit.text($r('app.string.json_err_nothing'));
  }
  if (code === JsonErrorCode.TOO_DEEP) {
    return ToolUiKit.stringOf($r('app.string.json_err_too_deep'), [args[0]]);
  }
  if (code === JsonErrorCode.UNEXPECTED_END) {
    return ToolUiKit.text($r('app.string.jtk_err_unexpected_end'));
  }
  if (code === JsonErrorCode.SINGLE_QUOTE_STRING) {
    return ToolUiKit.text($r('app.string.json_err_single_quote'));
  }
  if (code === JsonErrorCode.COMMENT) {
    return ToolUiKit.text($r('app.string.json_err_comment'));
  }
  if (code === JsonErrorCode.UNKNOWN_LITERAL) {
    return ToolUiKit.text($r('app.string.json_err_unknown_literal'));
  }
  if (code === JsonErrorCode.UNKNOWN_KEYWORD) {
    return ToolUiKit.text($r('app.string.json_err_unknown_keyword'));
  }
  if (code === JsonErrorCode.STRING_BACKSLASH_END) {
    return ToolUiKit.text($r('app.string.json_err_string_backslash'));
  }
  if (code === JsonErrorCode.STRING_CONTROL_CHAR) {
    return ToolUiKit.text($r('app.string.json_err_string_control'));
  }
  if (code === JsonErrorCode.STRING_UNTERMINATED) {
    return ToolUiKit.text($r('app.string.jtk_err_string_unterminated'));
  }
  if (code === JsonErrorCode.NUMBER_LEADING_ZERO) {
    return ToolUiKit.text($r('app.string.jtk_err_number_leading_zero'));
  }
  if (code === JsonErrorCode.NUMBER_MINUS) {
    return ToolUiKit.text($r('app.string.json_err_number_minus'));
  }
  if (code === JsonErrorCode.NUMBER_FRACTION) {
    return ToolUiKit.text($r('app.string.jtk_err_number_fraction'));
  }
  if (code === JsonErrorCode.NUMBER_EXPONENT) {
    return ToolUiKit.text($r('app.string.jtk_err_number_exponent'));
  }
  if (code === JsonErrorCode.OBJECT_UNCLOSED) {
    return ToolUiKit.text($r('app.string.jtk_err_object_unclosed'));
  }
  if (code === JsonErrorCode.OBJECT_KEY_SINGLE_QUOTE) {
    return ToolUiKit.text($r('app.string.json_err_object_key_single'));
  }
  if (code === JsonErrorCode.OBJECT_KEY_NOT_STRING) {
    return ToolUiKit.text($r('app.string.json_err_object_key_not_string'));
  }
  if (code === JsonErrorCode.OBJECT_COLON) {
    return ToolUiKit.text($r('app.string.jtk_err_object_colon'));
  }
  if (code === JsonErrorCode.OBJECT_TRAILING_COMMA) {
    return ToolUiKit.text($r('app.string.json_err_object_trailing_comma'));
  }
  if (code === JsonErrorCode.OBJECT_MISSING_COMMA) {
    return ToolUiKit.text($r('app.string.json_err_object_missing_comma'));
  }
  if (code === JsonErrorCode.ARRAY_TRAILING_COMMA) {
    return ToolUiKit.text($r('app.string.json_err_array_trailing_comma'));
  }
  if (code === JsonErrorCode.ARRAY_UNCLOSED) {
    return ToolUiKit.text($r('app.string.jtk_err_array_unclosed'));
  }
  if (code === JsonErrorCode.ARRAY_MISSING_COMMA) {
    return ToolUiKit.text($r('app.string.json_err_array_missing_comma'));
  }
  // 字符串反转义专用的两条
  if (code === JsonErrorCode.UNICODE_INCOMPLETE) {
    return ToolUiKit.text($r('app.string.jtk_err_unicode_incomplete'));
  }
  if (code === JsonErrorCode.UNICODE_BAD_HEX) {
    return ToolUiKit.stringOf($r('app.string.jtk_err_unicode_bad_hex'), [args[0]]);
  }
  if (code === JsonErrorCode.ESCAPE_UNSUPPORTED) {
    return ToolUiKit.stringOf($r('app.string.json_err_escape_unsupported'), [args[0]]);
  }
  return '';
}

/** 完整的错误一行：「原因（位置）」 */
export function jsonErrorTextOf(error: JsonError | null): string {
  if (error === null) {
    return '';
  }
  return ToolUiKit.stringOf($r('app.string.json_error_line'),
    [jsonReasonText(error.code, error.args), jsonPositionText(error)]);
}

/** 字符串转义/反转义的失败文案 */
export function jsonStringFailureText(code: JsonErrorCode, args: Array<string>): string {
  return jsonReasonText(code, args);
}

/** 根节点概要 */
export function jsonSummaryText(summary: JsonSummary): string {
  if (summary.empty) {
    return ToolUiKit.text($r('app.string.json_summary_none'));
  }
  if (summary.kind === JsonNodeKind.OBJECT) {
    return ToolUiKit.stringOf($r('app.string.json_summary_object'), [String(summary.count)]);
  }
  if (summary.kind === JsonNodeKind.ARRAY) {
    return ToolUiKit.stringOf($r('app.string.json_summary_array'), [String(summary.count)]);
  }
  if (summary.kind === JsonNodeKind.STRING) {
    return ToolUiKit.stringOf($r('app.string.json_summary_string'), [String(summary.count)]);
  }
  if (summary.kind === JsonNodeKind.NUMBER) {
    return ToolUiKit.stringOf($r('app.string.json_summary_number'), [summary.raw]);
  }
  if (summary.kind === JsonNodeKind.BOOLEAN) {
    return ToolUiKit.stringOf($r('app.string.json_summary_boolean'), [summary.raw]);
  }
  return ToolUiKit.text($r('app.string.json_summary_null'));
}

/** 重复键提示；没有重复键时返回空串 */
export function jsonDuplicateHintText(uniqueKeys: Array<string>): string {
  if (uniqueKeys.length === 0) {
    return '';
  }
  let joined: string = '';
  for (let i: number = 0; i < uniqueKeys.length; i++) {
    if (i > 0) {
      joined += ToolUiKit.text($r('app.string.json_list_separator'));
    }
    joined += uniqueKeys[i];
  }
  return ToolUiKit.stringOf($r('app.string.json_duplicate_hint'), [joined]);
}
