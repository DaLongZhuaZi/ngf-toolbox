/**
 * IP/CIDR 的显示文案（UI 层，失败码 → 资源键）。
 *
 * @module tools/ip-cidr/IpCidrMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { IpCidrFailure, IpCidrFailureCode } from './IpCidr';

/** 把失败码翻译成当前语言的句子；NONE 返回空串 */
export function ipCidrFailureText(failure: IpCidrFailure): string {
  if (failure.code === IpCidrFailureCode.EMPTY_INPUT) {
    return ToolUiKit.text($r('app.string.ic_err_empty'));
  }
  if (failure.code === IpCidrFailureCode.MISSING_PREFIX) {
    return ToolUiKit.text($r('app.string.ic_err_no_prefix'));
  }
  if (failure.code === IpCidrFailureCode.BAD_FORMAT) {
    return ToolUiKit.text($r('app.string.ic_err_format'));
  }
  if (failure.code === IpCidrFailureCode.PREFIX_OUT_OF_RANGE) {
    return ToolUiKit.stringOf($r('app.string.ic_err_prefix'), failure.args);
  }
  return '';
}
