/**
 * JSON 点路径的显示文案（UI 层，失败码 → 资源键）。
 *
 * @module tools/json-path/JsonPathMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { JsonPathFailure, JsonPathFailureCode } from './JsonPath';

/** 把失败码翻译成当前语言的句子；NONE 返回空串 */
export function jsonPathFailureText(failure: JsonPathFailure): string {
  if (failure.code === JsonPathFailureCode.EMPTY_INPUT) {
    return ToolUiKit.text($r('app.string.jp_err_empty_json'));
  }
  if (failure.code === JsonPathFailureCode.EMPTY_PATH) {
    return ToolUiKit.text($r('app.string.jp_err_empty_path'));
  }
  if (failure.code === JsonPathFailureCode.BAD_JSON) {
    return ToolUiKit.text($r('app.string.jp_err_bad_json'));
  }
  if (failure.code === JsonPathFailureCode.BAD_PATH_SYNTAX) {
    return ToolUiKit.text($r('app.string.jp_err_syntax'));
  }
  if (failure.code === JsonPathFailureCode.PATH_NOT_FOUND) {
    return ToolUiKit.stringOf($r('app.string.jp_err_not_found'), failure.args);
  }
  return '';
}
