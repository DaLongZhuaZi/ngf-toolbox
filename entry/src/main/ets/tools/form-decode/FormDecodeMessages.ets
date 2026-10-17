/**
 * 表单编码解析的显示文案（UI 层，失败码 → 资源键）。
 *
 * @module tools/form-decode/FormDecodeMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { FormDecodeFailure, FormDecodeFailureCode } from './FormDecode';

/** 把失败码翻译成当前语言的句子；NONE 返回空串 */
export function formDecodeFailureText(failure: FormDecodeFailure): string {
  if (failure.code === FormDecodeFailureCode.EMPTY_INPUT) {
    return ToolUiKit.text($r('app.string.fd_err_empty'));
  }
  if (failure.code === FormDecodeFailureCode.LEADING_QUESTION_MARK) {
    return ToolUiKit.text($r('app.string.fd_err_question'));
  }
  return '';
}
