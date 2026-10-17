/**
 * HTTP 状态码的显示文案（UI 层）。
 *
 * @module tools/http-status/HttpStatusMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';

/** 空态文案 */
export function httpStatusEmptyText(): string {
  return ToolUiKit.text($r('app.string.hs_empty'));
}
