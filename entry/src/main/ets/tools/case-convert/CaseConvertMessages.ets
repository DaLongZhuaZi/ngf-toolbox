/**
 * 命名风格转换的显示文案（UI 层，失败码 → 资源键）。
 *
 * @module tools/case-convert/CaseConvertMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { CaseFailure, CaseFailureCode } from './CaseConvert';

/** 把失败码翻译成当前语言的句子；NONE 返回空串 */
export function caseFailureText(failure: CaseFailure): string {
  if (failure.code === CaseFailureCode.EMPTY_INPUT) {
    return ToolUiKit.text($r('app.string.case_err_empty'));
  }
  if (failure.code === CaseFailureCode.NO_WORDS) {
    return ToolUiKit.stringOf($r('app.string.case_err_no_words'), failure.args);
  }
  return '';
}
