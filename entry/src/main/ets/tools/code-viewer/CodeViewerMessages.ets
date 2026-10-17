/**
 * 代码查看的显示文案（**UI 层**，可以 import ArkUI）。
 *
 * ## 为什么显示函数要放在这里而不是纯逻辑层
 *
 * 原先 \`describeDocument\` 与 \`rejectReason\` 住在 \`CodeHighlight.ets\`（纯逻辑），
 * 它们返回的是**拼好的中文句子**。这有两个问题：
 *
 * 1. 纯逻辑不能 import ArkUI 的 \`$r()\`，所以它没法按设备语言选文案；
 * 2. 更根本的是**分层错了**：它们是显示逻辑，本来就不该在纯逻辑层。
 *
 * 现在纯逻辑只提供**零件**（行数、是否截断、字符数、是否过大），
 * 句子在这里用资源键组装。这样每种语言都能自己决定语序与量词——
 * 中文说「3 行」，英文说 "3 lines"，靠 \`%s\` 占位而不是拼接。
 *
 * @module tools/code-viewer/CodeViewerMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import {
  CodeDocument,
  CodeLanguage,
  formatSize,
  languageLabel,
  MAX_FILE_CHARS,
  MAX_RENDER_LINES
} from './CodeHighlight';

/**
 * 语言展示名：专有名词直接用，需要翻译的两种走资源键。
 *
 * 每个分支都是**字面量** \`$r('app.string.…')\`——键必须是字面量（PR-013），
 * 也才能被 \`tools/verify/check-resources.mjs\` 核对是否存在。
 */
export function codeLanguageLabel(language: CodeLanguage): string {
  if (language === CodeLanguage.PLAIN) {
    return ToolUiKit.text($r('app.string.codeview_lang_plain'));
  }
  if (language === CodeLanguage.PROPERTIES) {
    return ToolUiKit.text($r('app.string.codeview_lang_properties'));
  }
  // 到这里说明是专有名词；万一将来新增了「需要翻译但忘了补分支」的语言，
  // languageNeedsResource 会为真而这里返回空串——那种情况会被下面的兜底盖住。
  const proper: string = languageLabel(language);
  if (proper.length === 0) {
    return ToolUiKit.text($r('app.string.codeview_lang_plain'));
  }
  return proper;
}

/** 文件名取不到时的占位（原先是纯逻辑里的一句中文） */
export function codeViewerUnnamedFile(): string {
  return ToolUiKit.text($r('app.string.codeview_unnamed_file'));
}

/**
 * 文档概要：语言 · 行数 · 大小（必要时附截断说明）。
 *
 * 整句做成一个资源键而不是拼接「…· … 行 · …」：中文的量词「行」在英文里是
 * "lines"，位置也不完全一样，拼接方案在翻译时必然要推倒重写。
 */
export function describeDocument(doc: CodeDocument): string {
  const head: string = ToolUiKit.stringOf($r('app.string.codeview_summary'),
    [codeLanguageLabel(doc.language), String(doc.totalLines), formatSize(doc.totalChars)]);
  if (!doc.truncated) {
    return head;
  }
  return head + ToolUiKit.stringOf($r('app.string.codeview_summary_truncated'),
    [String(MAX_RENDER_LINES)]);
}

/** 文件过大时的拒绝说明 */
export function fileTooLargeText(charCount: number): string {
  return ToolUiKit.stringOf($r('app.string.codeview_too_large'),
    [formatSize(charCount), formatSize(MAX_FILE_CHARS)]);
}

/** 是否超过只读查看上限（转调纯逻辑，页面只依赖本文件） */
export function fileTooLarge(charCount: number): boolean {
  return charCount > MAX_FILE_CHARS;
}
