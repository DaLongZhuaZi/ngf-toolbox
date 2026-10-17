/**
 * 占位文本生成的显示文案（UI 层，失败码 → 资源键）。
 *
 * @module tools/lorem-ipsum/LoremIpsumMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { LoremFailure, LoremFailureCode } from './LoremIpsum';

/** 把失败码翻译成当前语言的句子；NONE 返回空串 */
export function loremFailureText(failure: LoremFailure): string {
  if (failure.code === LoremFailureCode.COUNT_OUT_OF_RANGE) {
    return ToolUiKit.text($r('app.string.li_err_range'));
  }
  return '';
}
