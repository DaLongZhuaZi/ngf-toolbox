/**
 * URL 编解码的显示文案（UI 层，失败码 → 资源键）。
 *
 * 切分理由见 RadixConvertMessages.ets：纯逻辑只给「因为什么失败 + 参数」，
 * 按设备语言选句子是 UI 层的事。args 顺序必须与资源里 %s 的出现顺序一致。
 *
 * @module tools/url-codec/UrlCodecMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { UrlCodecFailure, UrlCodecFailureCode } from './UrlCodec';

/** 把失败码翻译成当前语言的句子；NONE 返回空串 */
export function urlCodecFailureText(failure: UrlCodecFailure): string {
  if (failure.code === UrlCodecFailureCode.EMPTY_INPUT) {
    return ToolUiKit.text($r('app.string.url_codec_err_empty'));
  }
  if (failure.code === UrlCodecFailureCode.MALFORMED_ESCAPE) {
    if (failure.args.length > 0) {
      return ToolUiKit.stringOf($r('app.string.url_codec_err_escape_at'), failure.args);
    }
    return ToolUiKit.text($r('app.string.url_codec_err_escape'));
  }
  return '';
}
