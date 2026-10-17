/**
 * 二维码工具的显示文案（**UI 层**，可以 import ArkUI）。
 *
 * 纯逻辑（\`QrPayload.ets\`）只给：失败原因码、类型双语名、长度提示的数字、缩短建议码。
 * 措辞全在这里——它不能 import ArkUI 的 \`$r()\`。
 *
 * 顺带修掉一个分层问题：成功结果原先要回传一句 \`kindLabel\`（「扫出来会被识别成什么」），
 * 但那句话就是请求里那个 kind 的显示名，页面本来就知道 kind。
 * 让纯逻辑回传一个已翻译好的字符串，等于把 UI 的活挪进了逻辑层。
 *
 * @module tools/qrcode/QrMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { NGFLocalizedText } from '../../core/ToolModel';
import {
  QrContentKind,
  QrHintCode,
  QrKindInfo,
  QrLengthNotice,
  QrPayloadFailure
} from './QrPayload';

/** 构造失败翻译成人话 */
export function qrFailureText(failure: QrPayloadFailure): string {
  if (failure === QrPayloadFailure.WIFI_SSID_REQUIRED) {
    return ToolUiKit.text($r('app.string.qr_err_wifi_ssid'));
  }
  if (failure === QrPayloadFailure.WIFI_PASSWORD_REQUIRED) {
    return ToolUiKit.text($r('app.string.qr_err_wifi_password'));
  }
  if (failure === QrPayloadFailure.VCARD_NAME_REQUIRED) {
    return ToolUiKit.text($r('app.string.qr_err_vcard_name'));
  }
  if (failure === QrPayloadFailure.URL_REQUIRED) {
    return ToolUiKit.text($r('app.string.qr_err_url_required'));
  }
  if (failure === QrPayloadFailure.URL_INVALID) {
    return ToolUiKit.text($r('app.string.qr_err_url_invalid'));
  }
  if (failure === QrPayloadFailure.TEXT_REQUIRED) {
    return ToolUiKit.text($r('app.string.qr_err_text_required'));
  }
  if (failure === QrPayloadFailure.PHONE_REQUIRED) {
    return ToolUiKit.text($r('app.string.qr_err_phone_required'));
  }
  if (failure === QrPayloadFailure.PHONE_NO_DIGITS) {
    return ToolUiKit.text($r('app.string.qr_err_phone_no_digits'));
  }
  if (failure === QrPayloadFailure.SMS_PHONE_REQUIRED) {
    return ToolUiKit.text($r('app.string.qr_err_sms_phone'));
  }
  if (failure === QrPayloadFailure.EMAIL_REQUIRED) {
    return ToolUiKit.text($r('app.string.qr_err_email_required'));
  }
  return ToolUiKit.text($r('app.string.qr_err_email_invalid'));
}

/** 类型选择器上的名字（双语数据按 locale 取） */
export function qrKindLabelText(info: QrKindInfo, locale: string): string {
  return info.label.forLocale(locale);
}

/**
 * 「扫出来会是……」那句话里的类型名。
 *
 * 与选择器上的短名**故意分开**：选择器上写「名片」省地方，
 * 结果里写「联系人名片」更清楚。两处各自成键，翻译时也能各自取舍。
 */
export function qrResultKindText(kind: QrContentKind): string {
  if (kind === QrContentKind.URL) {
    return ToolUiKit.text($r('app.string.qr_result_url'));
  }
  if (kind === QrContentKind.WIFI) {
    return ToolUiKit.text($r('app.string.qr_result_wifi'));
  }
  if (kind === QrContentKind.VCARD) {
    return ToolUiKit.text($r('app.string.qr_result_vcard'));
  }
  if (kind === QrContentKind.PHONE) {
    return ToolUiKit.text($r('app.string.qr_result_phone'));
  }
  if (kind === QrContentKind.SMS) {
    return ToolUiKit.text($r('app.string.qr_result_sms'));
  }
  if (kind === QrContentKind.EMAIL) {
    return ToolUiKit.text($r('app.string.qr_result_email'));
  }
  return ToolUiKit.text($r('app.string.qr_result_text'));
}

/** 内容过长的提示；没超长返回空串 */
export function lengthNoticeText(notice: QrLengthNotice): string {
  if (!notice.tooLong) {
    return '';
  }
  return ToolUiKit.stringOf($r('app.string.qr_notice_too_long'),
    [String(notice.length), String(notice.comfortable)]);
}

/** 缩短建议；没有建议返回空串 */
export function shorteningHintText(code: QrHintCode): string {
  if (code === QrHintCode.LONG_URL) {
    return ToolUiKit.text($r('app.string.qr_hint_long_url'));
  }
  if (code === QrHintCode.COULD_BE_URL) {
    return ToolUiKit.text($r('app.string.qr_hint_could_be_url'));
  }
  return '';
}

/** 双语数据取值（类型名以外的通用入口） */
export function localizedOf(text: NGFLocalizedText, locale: string): string {
  return text.forLocale(locale);
}
