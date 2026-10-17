/**
 * IEEE-754 位分解的显示文案（UI 层，失败码 → 资源键）。
 *
 * @module tools/float-bits/FloatBitsMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { FloatBitsFailure, FloatBitsFailureCode } from './FloatBits';

/** 把失败码翻译成当前语言的句子；NONE 返回空串 */
export function floatBitsFailureText(failure: FloatBitsFailure): string {
  if (failure.code === FloatBitsFailureCode.EMPTY_INPUT) {
    return ToolUiKit.text($r('app.string.fb_err_empty'));
  }
  if (failure.code === FloatBitsFailureCode.NOT_A_NUMBER) {
    return ToolUiKit.stringOf($r('app.string.fb_err_parse'), failure.args);
  }
  return '';
}
