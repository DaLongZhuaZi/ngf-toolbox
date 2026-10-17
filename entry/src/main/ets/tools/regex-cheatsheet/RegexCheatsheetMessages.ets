/**
 * 正则速查的显示文案（UI 层）。
 *
 * @module tools/regex-cheatsheet/RegexCheatsheetMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';

/** 空态文案 */
export function regexEmptyText(): string {
  return ToolUiKit.text($r('app.string.rc_empty'));
}
