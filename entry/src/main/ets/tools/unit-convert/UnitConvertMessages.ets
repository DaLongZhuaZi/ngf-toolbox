/**
 * 单位换算的显示文案（UI 层，失败码 → 资源键）。
 *
 * @module tools/unit-convert/UnitConvertMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { UnitFailure, UnitFailureCode } from './UnitConvert';

/** 把失败码翻译成当前语言的句子；NONE 返回空串 */
export function unitFailureText(failure: UnitFailure): string {
  if (failure.code === UnitFailureCode.EMPTY_VALUE) {
    return ToolUiKit.text($r('app.string.uc_err_empty'));
  }
  if (failure.code === UnitFailureCode.NOT_A_NUMBER) {
    return ToolUiKit.stringOf($r('app.string.uc_err_nan'), failure.args);
  }
  if (failure.code === UnitFailureCode.NEGATIVE) {
    return ToolUiKit.stringOf($r('app.string.uc_err_negative'), failure.args);
  }
  if (failure.code === UnitFailureCode.UNKNOWN_UNIT) {
    return ToolUiKit.stringOf($r('app.string.uc_err_unit'), failure.args);
  }
  return '';
}
