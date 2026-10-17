/**
 * JWT 解码器的显示文案（**UI 层**，可以 import ArkUI）。
 *
 * 纯逻辑只给失败码与结构：Base64URL 的失败、JSON 的失败（带位置）、
 * 时间换算的失败、相对时间的量级与方向。措辞全在这里。
 *
 * 「相对时间」是这一层存在的最好例子：中文说「已过去 3 天」，
 * 英文说 "3 days ago"，词序与介词都不同——纯逻辑给
 * （量级, 数量, 方向），怎么摆是每种语言自己的事。
 *
 * @module tools/jwt-decoder/JwtMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { NGFJsonFailure } from './JwtJson';
import {
  Base64UrlFailure,
  JwtDecodeFailure,
  JwtDecodeFailureCode,
  JwtRelative,
  JwtRelativeCode,
  JwtTimeFailure,
  NGFJwtClaim,
  TimeSpanUnit
} from './JwtDecoder';

/** Base64URL 失败翻译成人话 */
export function base64UrlFailureText(failure: Base64UrlFailure, args: Array<string>): string {
  if (failure === Base64UrlFailure.PAD_TOO_MANY) {
    return ToolUiKit.text($r('app.string.jwt_b64_pad_too_many'));
  }
  if (failure === Base64UrlFailure.EMPTY) {
    return ToolUiKit.text($r('app.string.jwt_b64_empty'));
  }
  if (failure === Base64UrlFailure.LENGTH_MOD1) {
    return ToolUiKit.text($r('app.string.jwt_b64_length'));
  }
  if (failure === Base64UrlFailure.BAD_CHAR) {
    return ToolUiKit.stringOf($r('app.string.jwt_b64_bad_char'), [args[0]]);
  }
  return ToolUiKit.text($r('app.string.jwt_b64_trailing_bits'));
}

/**
 * JSON 解析失败翻译成人话（带出错位置）。
 *
 * 位置单独成参数而不是拼进句子：中文写「第 1 行第 5 列」，
 * 英文写 "line 1, column 5"——连标点都不同，拼接必然要推倒重写。
 */
export function jsonFailureText(failure: NGFJsonFailure, args: Array<string>,
  line: number, column: number): string {
  const where: string = ToolUiKit.stringOf($r('app.string.jwt_json_position'),
    [String(line), String(column)]);
  return where + jsonReasonText(failure, args);
}

/** 只说「哪里不对」，不说位置 */
function jsonReasonText(failure: NGFJsonFailure, args: Array<string>): string {
  if (failure === NGFJsonFailure.ESCAPE_TRAILING) {
    return ToolUiKit.text($r('app.string.json_err_escape_trailing'));
  }
  if (failure === NGFJsonFailure.UNICODE_INCOMPLETE) {
    return ToolUiKit.text($r('app.string.json_err_unicode_incomplete'));
  }
  if (failure === NGFJsonFailure.UNICODE_BAD_HEX) {
    return ToolUiKit.text($r('app.string.json_err_unicode_bad_hex'));
  }
  if (failure === NGFJsonFailure.ESCAPE_UNKNOWN) {
    return ToolUiKit.stringOf($r('app.string.json_err_escape_unknown'), [args[0]]);
  }
  if (failure === NGFJsonFailure.STRING_UNTERMINATED) {
    return ToolUiKit.text($r('app.string.json_err_string_unterminated'));
  }
  if (failure === NGFJsonFailure.NUMBER_NO_DIGITS) {
    return ToolUiKit.text($r('app.string.json_err_number_no_digits'));
  }
  if (failure === NGFJsonFailure.NUMBER_LEADING_ZERO) {
    return ToolUiKit.text($r('app.string.json_err_number_leading_zero'));
  }
  if (failure === NGFJsonFailure.NUMBER_FRACTION) {
    return ToolUiKit.text($r('app.string.json_err_number_fraction'));
  }
  if (failure === NGFJsonFailure.NUMBER_EXPONENT) {
    return ToolUiKit.text($r('app.string.json_err_number_exponent'));
  }
  if (failure === NGFJsonFailure.LITERAL_EXPECTED) {
    return ToolUiKit.stringOf($r('app.string.json_err_literal_expected'), [args[0]]);
  }
  if (failure === NGFJsonFailure.ARRAY_UNCLOSED) {
    return ToolUiKit.text($r('app.string.json_err_array_unclosed'));
  }
  if (failure === NGFJsonFailure.ARRAY_UNEXPECTED) {
    return ToolUiKit.stringOf($r('app.string.json_err_array_unexpected'), [args[0]]);
  }
  if (failure === NGFJsonFailure.OBJECT_KEY_NOT_STRING) {
    return ToolUiKit.text($r('app.string.json_err_object_key'));
  }
  if (failure === NGFJsonFailure.OBJECT_COLON) {
    return ToolUiKit.text($r('app.string.json_err_object_colon'));
  }
  if (failure === NGFJsonFailure.OBJECT_UNCLOSED) {
    return ToolUiKit.text($r('app.string.json_err_object_unclosed'));
  }
  if (failure === NGFJsonFailure.OBJECT_UNEXPECTED) {
    return ToolUiKit.stringOf($r('app.string.json_err_object_unexpected'), [args[0]]);
  }
  if (failure === NGFJsonFailure.UNEXPECTED_END) {
    return ToolUiKit.text($r('app.string.json_err_unexpected_end'));
  }
  if (failure === NGFJsonFailure.UNEXPECTED_CHAR) {
    return ToolUiKit.stringOf($r('app.string.json_err_unexpected_char'), [args[0]]);
  }
  return ToolUiKit.text($r('app.string.json_err_trailing_content'));
}

/** 解码失败翻译成人话（含两处嵌套：Base64URL 与 JSON） */
export function jwtFailureText(failure: JwtDecodeFailure): string {
  if (failure.code === JwtDecodeFailureCode.EMPTY) {
    return ToolUiKit.text($r('app.string.jwt_err_empty'));
  }
  if (failure.code === JwtDecodeFailureCode.TOO_LONG) {
    return ToolUiKit.stringOf($r('app.string.jwt_err_too_long'), [failure.args[0]]);
  }
  if (failure.code === JwtDecodeFailureCode.JWE) {
    return ToolUiKit.text($r('app.string.jwt_err_jwe'));
  }
  if (failure.code === JwtDecodeFailureCode.WRONG_SEGMENTS) {
    return ToolUiKit.stringOf($r('app.string.jwt_err_segments'), [failure.args[0]]);
  }
  const inner: string = nestedText(failure);
  if (failure.code === JwtDecodeFailureCode.HEADER_BASE64) {
    return ToolUiKit.stringOf($r('app.string.jwt_err_header_b64'), [inner]);
  }
  if (failure.code === JwtDecodeFailureCode.PAYLOAD_BASE64) {
    return ToolUiKit.stringOf($r('app.string.jwt_err_payload_b64'), [inner]);
  }
  if (failure.code === JwtDecodeFailureCode.HEADER_JSON) {
    return ToolUiKit.stringOf($r('app.string.jwt_err_header_json'), [inner]);
  }
  return ToolUiKit.stringOf($r('app.string.jwt_err_payload_json'), [inner]);
}

/** 按外层码决定该翻译哪套内层原因 */
function nestedText(failure: JwtDecodeFailure): string {
  if (failure.code === JwtDecodeFailureCode.HEADER_BASE64
    || failure.code === JwtDecodeFailureCode.PAYLOAD_BASE64) {
    return base64UrlFailureText(failure.b64Code, failure.b64Args);
  }
  return jsonFailureText(failure.jsonCode, failure.jsonArgs, failure.line, failure.column);
}

/** 时间换算失败（成功时返回空串） */
export function jwtTimeFailureText(failure: JwtTimeFailure): string {
  if (failure === JwtTimeFailure.NOT_A_NUMBER) {
    return ToolUiKit.text($r('app.string.jwt_time_not_number'));
  }
  if (failure === JwtTimeFailure.OUT_OF_RANGE) {
    return ToolUiKit.text($r('app.string.jwt_time_out_of_range'));
  }
  return '';
}

/** 声明的可读时间：换算成功时补上本地时区标注 */
export function claimTimeText(claim: NGFJwtClaim): string {
  const failureText: string = jwtTimeFailureText(claim.timeFailure);
  if (failureText.length > 0) {
    return failureText;
  }
  return claim.dateTimeText + ToolUiKit.text($r('app.string.jwt_local_tz'));
}

/** 相对时间的措辞 */
export function claimRelativeText(relative: JwtRelative): string {
  if (relative.code === JwtRelativeCode.UNKNOWN) {
    return ToolUiKit.text($r('app.string.jwt_rel_unknown'));
  }
  if (relative.code === JwtRelativeCode.JUST_NOW) {
    return ToolUiKit.text($r('app.string.jwt_rel_just_now'));
  }
  const span: string = spanText(relative.unit, relative.value);
  return relative.code === JwtRelativeCode.PAST
    ? ToolUiKit.stringOf($r('app.string.jwt_rel_past'), [span])
    : ToolUiKit.stringOf($r('app.string.jwt_rel_future'), [span]);
}

/** 时间跨度（'3 天' / "3 days"） */
function spanText(unit: TimeSpanUnit, value: number): string {
  const text: string = String(value);
  if (unit === TimeSpanUnit.SECONDS) {
    return ToolUiKit.stringOf($r('app.string.jwt_span_seconds'), [text]);
  }
  if (unit === TimeSpanUnit.MINUTES) {
    return ToolUiKit.stringOf($r('app.string.jwt_span_minutes'), [text]);
  }
  if (unit === TimeSpanUnit.HOURS) {
    return ToolUiKit.stringOf($r('app.string.jwt_span_hours'), [text]);
  }
  if (unit === TimeSpanUnit.DAYS) {
    return ToolUiKit.stringOf($r('app.string.jwt_span_days'), [text]);
  }
  return ToolUiKit.stringOf($r('app.string.jwt_span_years'), [text]);
}

/** 声明的含义（exp / nbf / iat） */
export function claimLabelText(key: string): string {
  if (key === 'exp') {
    return ToolUiKit.text($r('app.string.jwt_claim_exp'));
  }
  if (key === 'nbf') {
    return ToolUiKit.text($r('app.string.jwt_claim_nbf'));
  }
  if (key === 'iat') {
    return ToolUiKit.text($r('app.string.jwt_claim_iat'));
  }
  return key;
}