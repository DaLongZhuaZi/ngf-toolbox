/**
 * 色板生成的显示文案（UI 层，失败码 → 资源键）。
 *
 * @module tools/palette-gen/PaletteGenMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { PaletteFailure, PaletteFailureCode } from './PaletteGen';

/** 把失败码翻译成当前语言的句子；NONE 返回空串 */
export function paletteFailureText(failure: PaletteFailure): string {
  if (failure.code === PaletteFailureCode.EMPTY_INPUT) {
    return ToolUiKit.text($r('app.string.pg_err_empty'));
  }
  if (failure.code === PaletteFailureCode.BAD_COLOR) {
    return ToolUiKit.stringOf($r('app.string.pg_err_bad'), failure.args);
  }
  return '';
}
