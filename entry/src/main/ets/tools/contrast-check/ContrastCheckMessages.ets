/**
 * 对比度检查的显示文案（UI 层，失败码 → 资源键）。
 *
 * @module tools/contrast-check/ContrastCheckMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { ContrastFailure, ContrastFailureCode } from './ContrastCheck';

/** 把失败码翻译成当前语言的句子；NONE 返回空串 */
export function contrastFailureText(failure: ContrastFailure): string {
  if (failure.code === ContrastFailureCode.EMPTY_INPUT) {
    return ToolUiKit.text($r('app.string.cc_err_empty'));
  }
  if (failure.code === ContrastFailureCode.SAME_COLOR) {
    return ToolUiKit.text($r('app.string.cc_err_same'));
  }
  return '';
}
