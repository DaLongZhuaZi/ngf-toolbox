/**
 * 编解码工具的显示文案（**UI 层**，可以 import ArkUI）。
 *
 * 纯逻辑（\`CodecLogic.ets\`）只给失败原因码与嵌套原因，措辞全在这里。
 * 模式名与模式说明原先也在纯逻辑层（\`codecModeLabel\` / \`codecModeHint\`），
 * 一起搬了过来——它们返回的是给用户看的文案。
 *
 * @module tools/codec-suite/CodecMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { CodecDirection, CodecFailure, CodecFailureCode, CodecMode } from './CodecLogic';

/**
 * 失败原因翻译成人话。
 *
 * 嵌套原因（Base64/Hex 解出来的字节不是合法 UTF-8）会拼成
 * 「外层一句话 + 内层一句话」。这里可以拼接，因为**两句各自是完整句子**；
 * 把词嵌进句子中间才是 i18n 的坑。
 */
export function codecFailureText(failure: CodecFailure): string {
  if (failure.code === CodecFailureCode.B64_NOT_UTF8
    || failure.code === CodecFailureCode.HEX_NOT_UTF8) {
    const outer: string = failure.code === CodecFailureCode.B64_NOT_UTF8
      ? ToolUiKit.text($r('app.string.codec_err_b64_not_utf8'))
      : ToolUiKit.text($r('app.string.codec_err_hex_not_utf8'));
    const inner: CodecFailure = new CodecFailure(failure.innerCode, failure.innerArgs,
      CodecFailureCode.NONE, []);
    return outer + codecFailureText(inner);
  }
  if (failure.code === CodecFailureCode.EMPTY) {
    return ToolUiKit.text($r('app.string.codec_err_empty'));
  }
  if (failure.code === CodecFailureCode.UTF8_TRUNCATED) {
    return ToolUiKit.text($r('app.string.codec_err_utf8_truncated'));
  }
  if (failure.code === CodecFailureCode.UTF8_BAD_CONTINUATION) {
    return ToolUiKit.text($r('app.string.codec_err_utf8_continuation'));
  }
  if (failure.code === CodecFailureCode.UTF8_OVERLONG) {
    return ToolUiKit.text($r('app.string.codec_err_utf8_overlong'));
  }
  if (failure.code === CodecFailureCode.UTF8_SURROGATE) {
    return ToolUiKit.text($r('app.string.codec_err_utf8_surrogate'));
  }
  if (failure.code === CodecFailureCode.UTF8_OUT_OF_RANGE) {
    return ToolUiKit.text($r('app.string.codec_err_utf8_range'));
  }
  if (failure.code === CodecFailureCode.UTF8_BAD_LEAD) {
    return ToolUiKit.stringOf($r('app.string.codec_err_utf8_lead'), [failure.args[0]]);
  }
  if (failure.code === CodecFailureCode.B64_TOO_MANY_PAD) {
    return ToolUiKit.text($r('app.string.codec_err_b64_pad_count'));
  }
  if (failure.code === CodecFailureCode.B64_PAD_NOT_AT_END) {
    return ToolUiKit.text($r('app.string.codec_err_b64_pad_position'));
  }
  if (failure.code === CodecFailureCode.B64_BAD_CHAR) {
    return ToolUiKit.stringOf($r('app.string.codec_err_b64_char'), [failure.args[0]]);
  }
  if (failure.code === CodecFailureCode.B64_LENGTH_MOD4) {
    return ToolUiKit.text($r('app.string.codec_err_b64_length'));
  }
  if (failure.code === CodecFailureCode.B64_PAD_MISMATCH) {
    return ToolUiKit.text($r('app.string.codec_err_b64_pad_mismatch'));
  }
  if (failure.code === CodecFailureCode.PERCENT_INCOMPLETE) {
    return ToolUiKit.text($r('app.string.codec_err_percent_incomplete'));
  }
  if (failure.code === CodecFailureCode.PERCENT_BAD) {
    return ToolUiKit.stringOf($r('app.string.codec_err_percent_bad'), [failure.args[0]]);
  }
  if (failure.code === CodecFailureCode.ESCAPE_TRAILING_BACKSLASH) {
    return ToolUiKit.text($r('app.string.codec_err_escape_trailing'));
  }
  if (failure.code === CodecFailureCode.UNICODE_INCOMPLETE) {
    return ToolUiKit.text($r('app.string.codec_err_unicode_incomplete'));
  }
  if (failure.code === CodecFailureCode.UNICODE_BAD_HEX) {
    return ToolUiKit.stringOf($r('app.string.codec_err_unicode_hex'), [failure.args[0]]);
  }
  if (failure.code === CodecFailureCode.ESCAPE_UNSUPPORTED) {
    return ToolUiKit.stringOf($r('app.string.codec_err_escape_unsupported'), [failure.args[0]]);
  }
  if (failure.code === CodecFailureCode.HEX_BAD_CHAR) {
    return ToolUiKit.stringOf($r('app.string.codec_err_hex_char'), [failure.args[0]]);
  }
  if (failure.code === CodecFailureCode.HEX_ODD_LENGTH) {
    return ToolUiKit.stringOf($r('app.string.codec_err_hex_odd'), [failure.args[0]]);
  }
  return '';
}

/** 模式名（Base64 / URL 整段 / …） */
export function codecModeText(mode: CodecMode): string {
  if (mode === CodecMode.BASE64) {
    return ToolUiKit.text($r('app.string.codec_mode_base64'));
  }
  if (mode === CodecMode.URL) {
    return ToolUiKit.text($r('app.string.codec_mode_url'));
  }
  if (mode === CodecMode.URL_COMPONENT) {
    return ToolUiKit.text($r('app.string.codec_mode_url_component'));
  }
  if (mode === CodecMode.UNICODE) {
    return ToolUiKit.text($r('app.string.codec_mode_unicode'));
  }
  return ToolUiKit.text($r('app.string.codec_mode_hex'));
}

/** 模式的一句话说明（页面在模式下方显示，省得用户猜该选哪个） */
export function codecModeHintText(mode: CodecMode): string {
  if (mode === CodecMode.BASE64) {
    return ToolUiKit.text($r('app.string.codec_hint_base64'));
  }
  if (mode === CodecMode.URL) {
    return ToolUiKit.text($r('app.string.codec_hint_url'));
  }
  if (mode === CodecMode.URL_COMPONENT) {
    return ToolUiKit.text($r('app.string.codec_hint_url_component'));
  }
  if (mode === CodecMode.UNICODE) {
    return ToolUiKit.text($r('app.string.codec_hint_unicode'));
  }
  return ToolUiKit.text($r('app.string.codec_hint_hex'));
}

/** 「编码」/「解码」 */
export function directionText(direction: CodecDirection): string {
  return direction === CodecDirection.ENCODE
    ? ToolUiKit.text($r('app.string.codec_dir_encode'))
    : ToolUiKit.text($r('app.string.codec_dir_decode'));
}
