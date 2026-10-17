/**
 * 摘要工具的结论翻译（**UI 层**，可以 import ArkUI）。
 *
 * 纯逻辑（{@link DigestAlgorithms}）只返回结论码与参数，见那里的说明。
 * 本文件负责把码翻成用户看得懂的话，并保证**每个分支一个的字面量 \`$r()\`**——
 * 键必须是字面量（PR-013），字面量也才能被 \`tools/verify/check-resources.mjs\` 核对。
 *
 * @module tools/digest/DigestMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { DigestCompareCode, DigestCompareOutcome } from './DigestAlgorithms';

/** 把指纹比对的结论码翻译成可直接显示的文案 */
export function digestCompareText(outcome: DigestCompareOutcome): string {
  const args: Array<string> = outcome.args;
  if (outcome.code === DigestCompareCode.EMPTY_EXPECTED) {
    return ToolUiKit.text($r('app.string.digest_compare_empty_expected'));
  }
  if (outcome.code === DigestCompareCode.NON_HEX) {
    return ToolUiKit.text($r('app.string.digest_compare_non_hex'));
  }
  if (outcome.code === DigestCompareCode.NO_ACTUAL) {
    return ToolUiKit.text($r('app.string.digest_compare_no_actual'));
  }
  if (outcome.code === DigestCompareCode.LENGTH_MISMATCH) {
    return ToolUiKit.stringOf($r('app.string.digest_compare_length_mismatch'), [args[0], args[1]]);
  }
  if (outcome.code === DigestCompareCode.MATCH) {
    return ToolUiKit.text($r('app.string.digest_compare_match'));
  }
  if (outcome.code === DigestCompareCode.MISMATCH) {
    return ToolUiKit.text($r('app.string.digest_compare_mismatch'));
  }
  // 结论码是枚举，走到这里说明加了新码却忘了补文案——返回空串而不是猜一个，
  // 空串在界面上是「什么也没显示」，比显示一句错误的话更容易被发现。
  return '';
}

/**
 * 交叉校验结果的文案。
 *
 * @param state 'running' | 'match' | 'diff' | 'unavailable'
 * @param same256 仅 state 为 'diff' 时有意义
 * @param same512 同上
 */
export function digestCrossCheckText(state: string, same256: boolean, same512: boolean): string {
  if (state === 'running') {
    return ToolUiKit.text($r('app.string.digest_cross_check_running'));
  }
  if (state === 'unavailable') {
    return ToolUiKit.text($r('app.string.digest_cross_check_unavailable'));
  }
  if (state === 'match') {
    return ToolUiKit.text($r('app.string.digest_cross_check_match'));
  }
  if (state === 'diff') {
    return ToolUiKit.stringOf($r('app.string.digest_cross_check_diff'), [
      same256
        ? ToolUiKit.text($r('app.string.digest_cross_same'))
        : ToolUiKit.text($r('app.string.digest_cross_different')),
      same512
        ? ToolUiKit.text($r('app.string.digest_cross_same'))
        : ToolUiKit.text($r('app.string.digest_cross_different'))
    ]);
  }
  return '';
}
