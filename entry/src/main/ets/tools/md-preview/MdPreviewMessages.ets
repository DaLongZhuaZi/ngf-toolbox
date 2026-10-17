/**
 * Markdown 预览的显示文案（UI 层）。
 *
 * @module tools/md-preview/MdPreviewMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';

/** 顶层提示与空态文案都只有一种状态，这里集中出口 */
export function mdEmptyText(): string {
  return ToolUiKit.text($r('app.string.md_empty'));
}
