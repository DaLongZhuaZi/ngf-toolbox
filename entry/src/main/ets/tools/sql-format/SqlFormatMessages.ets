/**
 * SQL 格式化的显示文案（UI 层，失败码 → 资源键）。
 *
 * @module tools/sql-format/SqlFormatMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { SqlFormatFailure, SqlFormatFailureCode } from './SqlFormat';

/** 把失败码翻译成当前语言的句子；NONE 返回空串 */
export function sqlFormatFailureText(failure: SqlFormatFailure): string {
  if (failure.code === SqlFormatFailureCode.EMPTY_INPUT) {
    return ToolUiKit.text($r('app.string.sf_err_empty'));
  }
  if (failure.code === SqlFormatFailureCode.UNCLOSED_QUOTE) {
    return ToolUiKit.text($r('app.string.sf_err_quote'));
  }
  return '';
}
