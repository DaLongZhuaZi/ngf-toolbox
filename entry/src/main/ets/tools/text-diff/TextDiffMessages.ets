/**
 * 文本 Diff 的显示文案（**UI 层**，可以 import ArkUI）。
 *
 * ## 这一层为什么必须存在
 *
 * \`TextDiff.ets\` 是纯逻辑：它不能 import ArkUI 的 \`$r()\`，所以：
 *
 * - 失败只返回**原因码 + 参数**（\`DiffFailure\`），不说人话；
 * - 原先的 \`summarizeDiff\` / \`lineEndingNotice\` / \`trailingNewlineNotice\`
 *   搬到了这里——它们是**显示逻辑**，住在纯逻辑层本身就是分层错误。
 *   纯逻辑留下的是「判断」（\`hasLineEndingMismatch\` 等），那些才是容易写错、
 *   值得单测覆盖的部分；措辞则因语言而异，不该被钉在纯逻辑里。
 *
 * ## 为什么「拼接句子」在这里是可以的
 *
 * 摘要由「一小句统计 + 可选的补充说明」拼成，看起来像拼接整句的坏味道。
 * 这里可以，是因为**每个片段本身就是一个完整句子**（资源键里带着句号），
 * 而不是把词嵌进句子的中间。后者才是真的坑：不同语言的语序不同，
 * 把词留成 \`%s\` 塞进整句里由翻译者决定位置，才是正确做法
 * （参见 digest 的 \`digest_cross_same\`）。
 *
 * @module tools/text-diff/TextDiffMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import {
  DiffDocument,
  DiffFailure,
  DiffFailureCode,
  DiffResult,
  DiffSummaryFacts,
  diffSummaryFacts,
  hasLineEndingMismatch,
  hasTrailingNewlineMismatch
} from './TextDiff';

/** 失败原因翻译成人话 */
export function diffFailureText(failure: DiffFailure): string {
  const args: Array<string> = failure.args;
  if (failure.code === DiffFailureCode.TOO_MANY_LINES) {
    return ToolUiKit.stringOf($r('app.string.diff_err_too_many_lines'),
      [args[0], args[1], args[2]]);
  }
  if (failure.code === DiffFailureCode.MATRIX_TOO_LARGE) {
    return ToolUiKit.stringOf($r('app.string.diff_err_matrix_too_large'), [args[0], args[1]]);
  }
  return '';
}

/** 一模一样时的那句话（页面顶部与「复制差异」共用，避免同一件事两种说法） */
function identicalSentence(kept: number): string {
  return ToolUiKit.stringOf($r('app.string.diff_identical'), [String(kept)]);
}

/**
 * 页面顶部的差异摘要。
 *
 * @returns 摘要文案；失败或没有结论时返回空串（错误另由 diffFailureText 显示）
 */
export function summarizeDiff(facts: DiffSummaryFacts): string {
  if (!facts.ok) {
    return '';
  }
  if (facts.identical) {
    return identicalSentence(facts.kept);
  }
  let summary: string = ToolUiKit.stringOf($r('app.string.diff_summary_counts'),
    [String(facts.added), String(facts.removed), String(facts.kept)]);
  if (facts.sameLineCountRewrite) {
    summary += ToolUiKit.text($r('app.string.diff_summary_same_line_count'));
  } else if (facts.lineCountDiffers) {
    summary += ToolUiKit.stringOf($r('app.string.diff_summary_line_counts'),
      [String(facts.leftLines), String(facts.rightLines)]);
  }
  return summary;
}

/**
 * 「复制差异」里那行统计。
 *
 * 与页面摘要分开是因为用途不同：这个会被粘进工单，需要更紧凑的写法
 * （不带句末标点、不附「逐行改写」这类解释）。
 */
export function unifiedSummaryLine(facts: DiffSummaryFacts): string {
  if (facts.identical) {
    return identicalSentence(facts.kept);
  }
  return ToolUiKit.stringOf($r('app.string.diff_unified_counts'),
    [String(facts.added), String(facts.removed), String(facts.kept)]);
}

/**
 * 行尾风格提示。
 *
 * 值得单独提示是因为它是**用户看不到却会被坑到**的一类差异：
 * 两段文本逐行内容一样，只因为一个是 CRLF、一个是 LF，
 * 在版本控制里会显示为「整个文件都改了」。判断在纯逻辑层，措辞在这里。
 */
export function lineEndingNotice(left: DiffDocument, right: DiffDocument): string {
  return hasLineEndingMismatch(left, right)
    ? ToolUiKit.text($r('app.string.diff_notice_line_ending'))
    : '';
}

/** 末尾换行差异提示 */
export function trailingNewlineNotice(left: DiffDocument, right: DiffDocument): string {
  return hasTrailingNewlineMismatch(left, right)
    ? ToolUiKit.text($r('app.string.diff_notice_trailing_newline'))
    : '';
}

/** 供页面把「复制差异」的统计行传进纯逻辑的 toUnifiedText */
export function unifiedSummaryOf(result: DiffResult, left: DiffDocument,
  right: DiffDocument): string {
  return unifiedSummaryLine(diffSummaryFacts(result, left, right));
}
