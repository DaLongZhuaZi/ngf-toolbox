/**
 * 校验和的显示文案（UI 层，失败码 → 资源键）。
 *
 * @module tools/checksum/ChecksumMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { ChecksumFailure, ChecksumFailureCode } from './Checksum';

/** 把失败码翻译成当前语言的句子；NONE 返回空串 */
export function checksumFailureText(failure: ChecksumFailure): string {
  if (failure.code === ChecksumFailureCode.EMPTY_INPUT) {
    return ToolUiKit.text($r('app.string.cs_err_empty'));
  }
  return '';
}
