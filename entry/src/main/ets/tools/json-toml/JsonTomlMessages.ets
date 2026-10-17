/**
 * TOML 解析的显示文案（UI 层，失败码 → 资源键）。
 *
 * @module tools/json-toml/JsonTomlMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { TomlFailure, TomlFailureCode } from './JsonToml';

/** 把失败码翻译成当前语言的句子；NONE 返回空串 */
export function tomlFailureText(failure: TomlFailure): string {
  if (failure.code === TomlFailureCode.EMPTY_INPUT) {
    return ToolUiKit.text($r('app.string.jt_err_empty'));
  }
  if (failure.code === TomlFailureCode.SYNTAX_ERROR) {
    return ToolUiKit.stringOf($r('app.string.jt_err_syntax'), failure.args);
  }
  if (failure.code === TomlFailureCode.UNSUPPORTED_MULTILINE) {
    return ToolUiKit.text($r('app.string.jt_err_multiline'));
  }
  return '';
}
