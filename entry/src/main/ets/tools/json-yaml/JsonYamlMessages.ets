/**
 * YAML 解析的显示文案（UI 层，失败码 → 资源键）。
 *
 * @module tools/json-yaml/JsonYamlMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { YamlFailure, YamlFailureCode } from './JsonYaml';

/** 把失败码翻译成当前语言的句子；NONE 返回空串 */
export function yamlFailureText(failure: YamlFailure): string {
  if (failure.code === YamlFailureCode.EMPTY_INPUT) {
    return ToolUiKit.text($r('app.string.jy_err_empty'));
  }
  if (failure.code === YamlFailureCode.SYNTAX_ERROR) {
    return ToolUiKit.stringOf($r('app.string.jy_err_syntax'), failure.args);
  }
  if (failure.code === YamlFailureCode.BAD_INDENT) {
    return ToolUiKit.stringOf($r('app.string.jy_err_indent'), failure.args);
  }
  if (failure.code === YamlFailureCode.UNSUPPORTED_BLOCK) {
    return ToolUiKit.text($r('app.string.jy_err_block'));
  }
  if (failure.code === YamlFailureCode.MULTI_DOCUMENT) {
    return ToolUiKit.text($r('app.string.jy_err_multi'));
  }
  return '';
}
