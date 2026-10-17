/**
 * HMAC 计算的显示文案（UI 层，失败码 → 资源键）。
 *
 * @module tools/hmac-calc/HmacCalcMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { HmacFailure, HmacFailureCode } from './HmacCalc';

/** 把失败码翻译成当前语言的句子；NONE 返回空串 */
export function hmacFailureText(failure: HmacFailure): string {
  if (failure.code === HmacFailureCode.EMPTY_MESSAGE) {
    return ToolUiKit.text($r('app.string.hmac_err_empty_message'));
  }
  if (failure.code === HmacFailureCode.EMPTY_KEY) {
    return ToolUiKit.text($r('app.string.hmac_err_empty_key'));
  }
  return '';
}
