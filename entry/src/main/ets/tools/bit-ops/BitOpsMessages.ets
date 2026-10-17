/**
 * 位运算器的显示文案（UI 层，失败码 → 资源键）。
 *
 * @module tools/bit-ops/BitOpsMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { BitOpsFailure, BitOpsFailureCode } from './BitOps';

/** 把失败码翻译成当前语言的句子；NONE 返回空串 */
export function bitOpsFailureText(failure: BitOpsFailure): string {
  if (failure.code === BitOpsFailureCode.EMPTY_LEFT) {
    return ToolUiKit.text($r('app.string.bo_err_empty_left'));
  }
  if (failure.code === BitOpsFailureCode.EMPTY_RIGHT) {
    return ToolUiKit.text($r('app.string.bo_err_empty_right'));
  }
  if (failure.code === BitOpsFailureCode.SHIFT_OUT_OF_RANGE) {
    return ToolUiKit.stringOf($r('app.string.bo_err_shift'), failure.args);
  }
  return '';
}
