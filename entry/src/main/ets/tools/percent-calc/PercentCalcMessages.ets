/**
 * 百分比计算的显示文案（UI 层，失败码 → 资源键）。
 *
 * @module tools/percent-calc/PercentCalcMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { PercentFailure, PercentFailureCode } from './PercentCalc';

/** 把失败码翻译成当前语言的句子；NONE 返回空串 */
export function percentFailureText(failure: PercentFailure): string {
  if (failure.code === PercentFailureCode.EMPTY_INPUT) {
    return ToolUiKit.text($r('app.string.pc_err_empty'));
  }
  if (failure.code === PercentFailureCode.NOT_A_NUMBER) {
    return ToolUiKit.text($r('app.string.pc_err_nan'));
  }
  if (failure.code === PercentFailureCode.DIVIDE_BY_ZERO) {
    return ToolUiKit.text($r('app.string.pc_err_zero'));
  }
  return '';
}
