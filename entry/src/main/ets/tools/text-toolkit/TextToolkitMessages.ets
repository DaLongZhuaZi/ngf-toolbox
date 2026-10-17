/**
 * 文本行工具的显示文案（UI 层，失败码 → 资源键）。
 *
 * @module tools/text-toolkit/TextToolkitMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { TextToolkitFailure, TextToolkitFailureCode } from './TextToolkit';

/** 把失败码翻译成当前语言的句子；NONE 返回空串 */
export function textToolkitFailureText(failure: TextToolkitFailure): string {
  if (failure.code === TextToolkitFailureCode.EMPTY_INPUT) {
    return ToolUiKit.text($r('app.string.tk_err_empty'));
  }
  if (failure.code === TextToolkitFailureCode.NO_CONTENT) {
    return ToolUiKit.text($r('app.string.tk_err_no_content'));
  }
  return '';
}
