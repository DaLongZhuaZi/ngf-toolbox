/**
 * HTML 实体的显示文案（UI 层，失败码 → 资源键）。
 *
 * @module tools/html-entity/HtmlEntityMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { HtmlEntityFailure, HtmlEntityFailureCode } from './HtmlEntity';

/** 把失败码翻译成当前语言的句子；NONE 返回空串 */
export function htmlEntityFailureText(failure: HtmlEntityFailure): string {
  if (failure.code === HtmlEntityFailureCode.EMPTY_INPUT) {
    return ToolUiKit.text($r('app.string.he_err_empty'));
  }
  if (failure.code === HtmlEntityFailureCode.UNKNOWN_NAMED) {
    return ToolUiKit.stringOf($r('app.string.he_err_unknown'), failure.args);
  }
  if (failure.code === HtmlEntityFailureCode.CODE_POINT_OUT_OF_RANGE) {
    return ToolUiKit.stringOf($r('app.string.he_err_range'), failure.args);
  }
  if (failure.code === HtmlEntityFailureCode.MISSING_SEMICOLON) {
    return ToolUiKit.text($r('app.string.he_err_semicolon'));
  }
  return '';
}
