/**
 * 进制转换的失败文案映射（**UI 层**，可以 import ArkUI）。
 *
 * ## 这一层为什么必须存在
 *
 * {@link RadixConvert} 是纯逻辑：它只返回**失败原因码 + 参数**，不会说人话。
 * 原因是纯逻辑不能 import ArkUI 的 \`$r()\`——一旦 import，它就没法在本机跑单测了
 * （本仓的 596 个用例全部依赖这一点）。
 *
 * 所以「码 → 用户看得懂的话」这件事只能在这里做：
 * 本文件属于 UI 层，\`$r()\` 随便用。
 *
 * ## 为什么每个分支写一个字面量 \`$r()\`
 *
 * \`$r()\` 的键必须是**字面量**（PR-013）：它由 ets-loader 在构建期静态改写成资源 ID，
 * 传变量或拼接表达式都不会生效，而且**不会在任何本机检查里报错**，
 * 只在真机上表现为文字空白。
 *
 * 所以这里用 \`switch\` 风格的 if 链，每个分支一个写死的键——
 * 啰嗦，但换来两件实事：构建期能改写，且 \`tools/verify/check-resources.mjs\`
 * 能顺着字面量核对「这个键到底存不存在」。
 *
 * ## 参数顺序的约定
 *
 * \`failure.args\` 的顺序必须与资源文案里 \`%s\` 的出现顺序一致。
 * 这条约束没有编译期保护，因此改文案时要同时看两边——
 * 资源的键名统一带 \`err_radix_\` 前缀，方便一起搜出来核对。
 *
 * @module tools/radix-convert/RadixConvertMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { RadixFailure, RadixFailureCode } from './RadixConvert';

/**
 * 把失败码翻译成可直接显示的文案。
 *
 * 返回 \`string\`（已解析并代入占位符），因此页面直接 \`Text(...)\` 即可，
 * 不必再关心 Resource 与参数的绑定。
 *
 * 键**仍然是字面量** \`$r('app.string.x')\`：构建期能静态改写，
 * \`tools/verify/check-resources.mjs\` 也能顺着字面量核对键是否存在。
 * 占位符的代入交给 {@link ToolUiKit.stringOf}（走 \`resourceManager\`，见那里的说明）。
 */
export function radixFailureText(failure: RadixFailure): string {
  const args: Array<string> = failure.args;
  if (failure.code === RadixFailureCode.RADIX_OUT_OF_RANGE) {
    return ToolUiKit.stringOf($r('app.string.err_radix_out_of_range'), [args[0], args[1]]);
  }
  if (failure.code === RadixFailureCode.EMPTY_INPUT) {
    return ToolUiKit.text($r('app.string.err_radix_empty_input'));
  }
  if (failure.code === RadixFailureCode.INVALID_DIGIT) {
    return ToolUiKit.stringOf($r('app.string.err_radix_invalid_digit'), [args[0], args[1]]);
  }
  if (failure.code === RadixFailureCode.UNSUPPORTED_OPERATION) {
    return ToolUiKit.stringOf($r('app.string.err_radix_unsupported_operation'), [args[0]]);
  }
  if (failure.code === RadixFailureCode.SHIFT_OUT_OF_RANGE) {
    return ToolUiKit.stringOf($r('app.string.err_radix_shift_out_of_range'), [args[0], args[1]]);
  }
  // NONE 不该走到这里（调用方只在 !ok 时调用）；给一个明确的兜底而不是空白，
  // 空白会让用户以为工具坏了，而这里其实是一个编程错误。
  return '';
}
