/**
 * JWT 解码的纯逻辑实现（**只解码，不验签**）。
 *
 * ## 这个工具刻意不做的事
 *
 * 不校验签名。判断令牌真伪需要密钥或公钥，而本 App 是零权限、零联网、零账号的
 * 本地工具，拿不到也不该保存那些材料。所以页面的 limitation 里必须写明：
 * 「能读到内容」不等于「令牌是真的」——解码出漂亮的 JSON 完全不代表它没被伪造。
 *
 * ## 为什么 Base64URL 与 UTF-8 都自己实现
 *
 * ArkTS 的 Base64/TextDecoder 来自设备能力（@ohos.util / @kit.ArkTS），
 * 纯逻辑一旦 import 它们，`entry/src/test` 的本地单测就跑不起来（分层门禁）。
 * 两者的规矩都很短：Base64URL 是 Base64 的 URL 安全变体（`-`→62、`_`→63，省略 padding），
 * UTF-8 是变长编码。自己实现还能顺手做**严格校验**：
 * 非法 Base64 必须报错，而不是解出一串乱码让用户以为令牌有问题。
 *
 * @module tools/jwt-decoder/JwtDecoder
 */

import {
  findTopLevelNumberText,
  findTopLevelStringText,
  formatJsonNode,
  NGFJsonFailure,
  NGFJsonKind,
  NGFJsonNode,
  NGFJsonParseResult,
  parseJson
} from './JwtJson';

/** token 长度上限（字符）。本工具用于查看单个令牌，超长输入多半是粘错了内容 */
export const JWT_MAX_TOKEN_LENGTH: number = 65536;

/** 标准 Base64 字符表；URL 安全变体的两个特殊字符单独判断 */
const BASE64_ALPHABET: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

/** Base64URL 解码结果 */
/** JWT 解码失败的原因码 */
export enum JwtDecodeFailureCode {
  NONE = 'none',
  EMPTY = 'empty',
  TOO_LONG = 'too_long',
  JWE = 'jwe',
  WRONG_SEGMENTS = 'wrong_segments',
  HEADER_BASE64 = 'header_base64',
  PAYLOAD_BASE64 = 'payload_base64',
  HEADER_JSON = 'header_json',
  PAYLOAD_JSON = 'payload_json'
}

/** 相对时间的量级 */
export enum TimeSpanUnit {
  SECONDS = 'seconds',
  MINUTES = 'minutes',
  HOURS = 'hours',
  DAYS = 'days',
  YEARS = 'years'
}

/** 相对时间的形态 */
/** 时间换算失败的原因码 */
export enum JwtTimeFailure {
  NONE = 'none',
  NOT_A_NUMBER = 'not_a_number',
  OUT_OF_RANGE = 'out_of_range'
}

/** 时间换算结果 */
export class JwtTimeResult {
  readonly failure: JwtTimeFailure;
  /** 'YYYY-MM-DD HH:mm:ss'；失败时为空串。**时区标注不在这里**，那句归 UI 层 */
  readonly dateTimeText: string;

  constructor(failure: JwtTimeFailure, dateTimeText: string) {
    this.failure = failure;
    this.dateTimeText = dateTimeText;
  }
}

/** 相对时间的结构化结果 */
export class JwtRelative {
  readonly code: JwtRelativeCode;
  readonly unit: TimeSpanUnit;
  readonly value: number;

  constructor(code: JwtRelativeCode, unit: TimeSpanUnit, value: number) {
    this.code = code;
    this.unit = unit;
    this.value = value;
  }
}

export enum JwtRelativeCode {
  /** 无法判断（秒值不是数字或超范围） */
  UNKNOWN = 'unknown',
  JUST_NOW = 'just_now',
  PAST = 'past',
  FUTURE = 'future'
}

/**
 * 解码失败的结构化原因。
 *
 * 四类失败其实是**下游的失败**（Header/Payload 的 Base64URL 解不开、或解出来不是合法 JSON），
 * 所以除了外层码还要带内层码与位置。压成一句 string 就没法翻译：
 * 译文里「第 N 行第 M 列」的位置与标点都不同。
 */
export class JwtDecodeFailure {
  readonly code: JwtDecodeFailureCode;
  readonly args: Array<string>;
  /** Base64URL 内层失败 */
  readonly b64Code: Base64UrlFailure;
  readonly b64Args: Array<string>;
  /** JSON 内层失败 */
  readonly jsonCode: NGFJsonFailure;
  readonly jsonArgs: Array<string>;
  readonly line: number;
  readonly column: number;

  constructor(code: JwtDecodeFailureCode, args: Array<string>, b64Code: Base64UrlFailure,
    b64Args: Array<string>, jsonCode: NGFJsonFailure, jsonArgs: Array<string>,
    line: number, column: number) {
    this.code = code;
    this.args = args;
    this.b64Code = b64Code;
    this.b64Args = b64Args;
    this.jsonCode = jsonCode;
    this.jsonArgs = jsonArgs;
    this.line = line;
    this.column = column;
  }

  static none(): JwtDecodeFailure {
    return new JwtDecodeFailure(JwtDecodeFailureCode.NONE, [], Base64UrlFailure.NONE, [],
      NGFJsonFailure.NONE, [], 0, 0);
  }
}

/** Base64URL 解码失败的原因码 */
export enum Base64UrlFailure {
  NONE = 'none',
  /** = 补齐超过两个 */
  PAD_TOO_MANY = 'pad_too_many',
  /** 片段为空 */
  EMPTY = 'empty',
  /** 去掉 = 之后余 1 个字符，凑不出完整字节 */
  LENGTH_MOD1 = 'length_mod1',
  /** 含有非法字符 */
  BAD_CHAR = 'bad_char',
  /** 末尾有多余的填充位（非零） */
  TRAILING_BITS = 'trailing_bits'
}

/** Base64URL 解码结果 */
export class NGFBase64UrlResult {
  readonly ok: boolean;
  readonly bytes: Uint8Array;
  readonly failure: Base64UrlFailure;
  /** 资源文案的占位符参数 */
  readonly args: Array<string>;

  constructor(ok: boolean, bytes: Uint8Array, failure: Base64UrlFailure, args: Array<string>) {
    this.ok = ok;
    this.bytes = bytes;
    this.failure = failure;
    this.args = args;
  }

  static success(bytes: Uint8Array): NGFBase64UrlResult {
    return new NGFBase64UrlResult(true, bytes, Base64UrlFailure.NONE, []);
  }

  static fail(failure: Base64UrlFailure, args: Array<string>): NGFBase64UrlResult {
    return new NGFBase64UrlResult(false, new Uint8Array(0), failure, args);
  }
}

/** 单个 Base64URL 字符的 6 位值；非法字符返回 -1 */
function base64ValueOf(ch: string): number {
  if (ch === '-') {
    return 62;
  }
  if (ch === '_') {
    return 63;
  }
  return BASE64_ALPHABET.indexOf(ch);
}

/**
 * 解码 Base64URL 片段。
 *
 * 严格程度是刻意的：字符非法、长度余 1、末尾多余位非零都算错误。
 * 宽松解码会把「用户粘错了一段」变成「解出一堆乱码」，后者更难排查。
 */
export function decodeBase64Url(segment: string): NGFBase64UrlResult {
  let text: string = segment.trim();
  let padding: number = 0;
  while (text.length > 0 && text.charAt(text.length - 1) === '=') {
    text = text.substring(0, text.length - 1);
    padding++;
  }
  if (padding > 2) {
    return NGFBase64UrlResult.fail(Base64UrlFailure.PAD_TOO_MANY, []);
  }
  if (text.length === 0) {
    return NGFBase64UrlResult.fail(Base64UrlFailure.EMPTY, []);
  }
  if (text.length % 4 === 1) {
    return NGFBase64UrlResult.fail(Base64UrlFailure.LENGTH_MOD1, []);
  }
  const bytes: number[] = [];
  let index: number = 0;
  while (index < text.length) {
    const remain: number = text.length - index;
    const groupSize: number = remain >= 4 ? 4 : remain;
    const values: number[] = [];
    for (let i: number = 0; i < groupSize; i++) {
      const value: number = base64ValueOf(text.charAt(index + i));
      if (value < 0) {
        return NGFBase64UrlResult.fail(
          Base64UrlFailure.BAD_CHAR, [text.charAt(index + i)]);
      }
      values.push(value);
    }
    if (groupSize === 4) {
      const packed: number = (values[0] << 18) | (values[1] << 12) | (values[2] << 6) | values[3];
      bytes.push((packed >> 16) & 0xff, (packed >> 8) & 0xff, packed & 0xff);
    } else if (groupSize === 3) {
      if ((values[2] & 0x03) !== 0) {
        return NGFBase64UrlResult.fail(Base64UrlFailure.TRAILING_BITS, []);
      }
      const packed: number = (values[0] << 12) | (values[1] << 6) | values[2];
      bytes.push((packed >> 10) & 0xff, (packed >> 2) & 0xff);
    } else {
      if ((values[1] & 0x0f) !== 0) {
        return NGFBase64UrlResult.fail(Base64UrlFailure.TRAILING_BITS, []);
      }
      const packed: number = (values[0] << 6) | values[1];
      bytes.push((packed >> 4) & 0xff);
    }
    index += groupSize;
  }
  const out: Uint8Array = new Uint8Array(bytes.length);
  for (let i: number = 0; i < bytes.length; i++) {
    out[i] = bytes[i];
  }
  return NGFBase64UrlResult.success(out);
}

/**
 * 把 UTF-8 字节解码成字符串。
 *
 * 非法序列替换为 U+FFFD（`\uFFFD`）而不是抛异常或静默丢弃：
 * 用户会看到「这里是坏的」，位置信息保留，排查比"少几个字"容易得多。
 */
export function decodeUtf8(bytes: Uint8Array): string {
  const replacement: string = String.fromCharCode(0xfffd);
  let out: string = '';
  let index: number = 0;
  while (index < bytes.length) {
    const first: number = bytes[index];
    if (first < 0x80) {
      out += String.fromCharCode(first);
      index++;
      continue;
    }
    let continuation: number = 0;
    let value: number = 0;
    if (first >= 0xc2 && first <= 0xdf) {
      continuation = 1;
      value = first & 0x1f;
    } else if (first >= 0xe0 && first <= 0xef) {
      continuation = 2;
      value = first & 0x0f;
    } else if (first >= 0xf0 && first <= 0xf4) {
      continuation = 3;
      value = first & 0x07;
    } else {
      out += replacement;
      index++;
      continue;
    }
    if (index + continuation >= bytes.length) {
      out += replacement;
      index++;
      continue;
    }
    let valid: boolean = true;
    for (let i: number = 1; i <= continuation; i++) {
      const next: number = bytes[index + i];
      if ((next & 0xc0) !== 0x80) {
        valid = false;
        break;
      }
      value = (value << 6) | (next & 0x3f);
    }
    if (!valid) {
      out += replacement;
      index++;
      continue;
    }
    if (value > 0xffff) {
      const adjusted: number = value - 0x10000;
      out += String.fromCharCode(0xd800 + (adjusted >> 10), 0xdc00 + (adjusted & 0x3ff));
    } else {
      out += String.fromCharCode(value);
    }
    index += continuation + 1;
  }
  return out;
}

/** 一条时间类声明的解读结果 */
export class NGFJwtClaim {
  /** 原始键名（'exp' / 'iat' / 'nbf'） */
  readonly key: string;
  /** 原始数值文本（不转 number，避免大整数被改写） */
  readonly rawValue: string;
  /** 换算成 'YYYY-MM-DD HH:mm:ss'；无法换算时为空串。时区标注不在这里，那句归 UI 层 */
  readonly dateTimeText: string;
  /** 时间换算失败原因（成功时为 NONE） */
  readonly timeFailure: JwtTimeFailure;
  /** 与「现在」的相对关系（措辞归 UI 层） */
  readonly relative: JwtRelative;

  constructor(key: string, rawValue: string, dateTimeText: string,
    timeFailure: JwtTimeFailure, relative: JwtRelative) {
    this.key = key;
    this.rawValue = rawValue;
    this.dateTimeText = dateTimeText;
    this.timeFailure = timeFailure;
    this.relative = relative;
  }
}
/** 一份 JWT 的解码结果 */
export class NGFJwtDecodeResult {
  readonly ok: boolean;
  /** 失败原因；成功时为 {@link JwtDecodeFailure.none}（**永不为 null**） */
  readonly failure: JwtDecodeFailure;
  /** 段数（3 段正常；5 段是 JWE，本工具不支持） */
  readonly segmentCount: number;
  /** 三段原文 */
  readonly headerRaw: string;
  readonly payloadRaw: string;
  readonly signature: string;
  /** 美化后的 Header / Payload */
  readonly headerJson: string;
  readonly payloadJson: string;
  /** Header 里的 alg / typ（取不到为空串） */
  readonly algorithm: string;
  readonly tokenType: string;
  /** exp / iat / nbf 的解读（缺失的不会有条目） */
  readonly claims: NGFJwtClaim[];
  /** 是否存在 exp 声明 */
  readonly hasExpiration: boolean;
  /** 是否已过期（没有 exp 时为 false，页面需另行说明「无过期时间」） */
  readonly expired: boolean;

  constructor(ok: boolean, failure: JwtDecodeFailure, segmentCount: number, headerRaw: string, payloadRaw: string,
    signature: string, headerJson: string, payloadJson: string, algorithm: string, tokenType: string,
    claims: NGFJwtClaim[], hasExpiration: boolean, expired: boolean) {
    this.ok = ok;
    this.failure = failure;
    this.segmentCount = segmentCount;
    this.headerRaw = headerRaw;
    this.payloadRaw = payloadRaw;
    this.signature = signature;
    this.headerJson = headerJson;
    this.payloadJson = payloadJson;
    this.algorithm = algorithm;
    this.tokenType = tokenType;
    this.claims = claims;
    this.hasExpiration = hasExpiration;
    this.expired = expired;
  }

  /** 只带一个外层码 */
  static fail(code: JwtDecodeFailureCode, segmentCount: number): NGFJwtDecodeResult {
    return new NGFJwtDecodeResult(false, new JwtDecodeFailure(code, [], Base64UrlFailure.NONE, [],
      NGFJsonFailure.NONE, [], 0, 0), segmentCount, '', '', '', '', '', '', '', [], false, false);
  }

  static failWithArgs(code: JwtDecodeFailureCode, args: Array<string>, segmentCount: number): NGFJwtDecodeResult {
    return new NGFJwtDecodeResult(false, new JwtDecodeFailure(code, args, Base64UrlFailure.NONE, [],
      NGFJsonFailure.NONE, [], 0, 0), segmentCount, '', '', '', '', '', '', '', [], false, false);
  }

  /** Base64URL 内层失败 */
  static failBase64(code: JwtDecodeFailureCode, inner: NGFBase64UrlResult,
    segmentCount: number): NGFJwtDecodeResult {
    return new NGFJwtDecodeResult(false, new JwtDecodeFailure(code, [], inner.failure, inner.args,
      NGFJsonFailure.NONE, [], 0, 0), segmentCount, '', '', '', '', '', '', '', [], false, false);
  }

  /** JSON 内层失败（带出错位置） */
  static failJson(code: JwtDecodeFailureCode, inner: NGFJsonParseResult,
    segmentCount: number): NGFJwtDecodeResult {
    return new NGFJwtDecodeResult(false, new JwtDecodeFailure(code, [], Base64UrlFailure.NONE, [],
      inner.failure, inner.args, inner.position.line, inner.position.column), segmentCount,
      '', '', '', '', '', '', '', [], false, false);
  }
}

/**
 * 把秒级时间戳文本转成可读的本地时间。
 *
 * 越界（超出 Date 能表示的范围、或根本不是数字）时返回原因说明而不是空串：
 * 用户看到「为什么没有时间」比看到一片空白更有用。
 */
export function formatTimestampSeconds(secondsText: string): JwtTimeResult {
  const seconds: number = Number(secondsText);
  if (isNaN(seconds)) {
    return new JwtTimeResult(JwtTimeFailure.NOT_A_NUMBER, '');
  }
  const milliseconds: number = seconds * 1000;
  const date: Date = new Date(milliseconds);
  const time: number = date.getTime();
  if (isNaN(time)) {
    return new JwtTimeResult(JwtTimeFailure.OUT_OF_RANGE, '');
  }
  // 注意这里**不带**「（本地时区）」：那句是文案，归 UI 层。
  // 日期数字本身是国际通用写法，不需要翻译。
  return new JwtTimeResult(JwtTimeFailure.NONE,
    pad4(date.getFullYear()) + '-' + pad2(date.getMonth() + 1) + '-' + pad2(date.getDate())
    + ' ' + pad2(date.getHours()) + ':' + pad2(date.getMinutes()) + ':' + pad2(date.getSeconds()));
}

function pad2(value: number): string {
  const text: string = String(value);
  return text.length >= 2 ? text : '0' + text;
}

function pad4(value: number): string {
  let text: string = String(value);
  while (text.length < 4) {
    text = '0' + text;
  }
  return text;
}

/** 把毫秒差说成「已过期 3 天 / 还有 2 小时 / 刚刚」 */
export function describeRelative(secondsText: string, nowMilliseconds: number): JwtRelative {
  const seconds: number = Number(secondsText);
  if (isNaN(seconds)) {
    return new JwtRelative(JwtRelativeCode.UNKNOWN, TimeSpanUnit.SECONDS, 0);
  }
  const difference: number = nowMilliseconds - seconds * 1000;
  const absolute: number = difference < 0 ? -difference : difference;
  const minutes: number = Math.floor(absolute / 60000);
  const hours: number = Math.floor(absolute / 3600000);
  const days: number = Math.floor(absolute / 86400000);
  // 只给「量级 + 数量 + 方向」，不给措辞：
  // 中文说「已过去 3 天」，英文说 "3 days ago"，词序与介词都不同。
  if (absolute < 1000) {
    return new JwtRelative(JwtRelativeCode.JUST_NOW, TimeSpanUnit.SECONDS, 0);
  }
  const code: JwtRelativeCode = difference > 0 ? JwtRelativeCode.PAST : JwtRelativeCode.FUTURE;
  if (absolute < 60000) {
    return new JwtRelative(code, TimeSpanUnit.SECONDS, Math.floor(absolute / 1000));
  }
  if (minutes < 60) {
    return new JwtRelative(code, TimeSpanUnit.MINUTES, minutes);
  }
  if (hours < 24) {
    return new JwtRelative(code, TimeSpanUnit.HOURS, hours);
  }
  if (days < 365) {
    return new JwtRelative(code, TimeSpanUnit.DAYS, days);
  }
  return new JwtRelative(code, TimeSpanUnit.YEARS, Math.floor(days / 365));
}

/** 构造一条声明解读 */
function buildClaim(key: string, rawValue: string, nowMilliseconds: number): NGFJwtClaim {
  const time: JwtTimeResult = formatTimestampSeconds(rawValue);
  return new NGFJwtClaim(key, rawValue, time.dateTimeText, time.failure,
    describeRelative(rawValue, nowMilliseconds));
}

/**
 * 解码一个 JWT。
 *
 * @param token JWT 原文
 * @param nowMilliseconds 当前时间（毫秒）。**由调用方传入**而不是内部取 Date.now()：
 *        过期判断是这套逻辑里最容易被时区/时钟影响的部分，显式传入才能被单测固定住。
 */
export function decodeJwt(token: string, nowMilliseconds: number): NGFJwtDecodeResult {
  const trimmed: string = token.trim();
  if (trimmed.length === 0) {
    return NGFJwtDecodeResult.fail(JwtDecodeFailureCode.EMPTY, 0);
  }
  if (trimmed.length > JWT_MAX_TOKEN_LENGTH) {
    return NGFJwtDecodeResult.failWithArgs(JwtDecodeFailureCode.TOO_LONG,
      [String(JWT_MAX_TOKEN_LENGTH)], 0);
  }
  const parts: string[] = trimmed.split('.');
  if (parts.length === 5) {
    return NGFJwtDecodeResult.fail(JwtDecodeFailureCode.JWE, 5);
  }
  if (parts.length !== 3) {
    return NGFJwtDecodeResult.failWithArgs(JwtDecodeFailureCode.WRONG_SEGMENTS,
      [String(parts.length)], parts.length);
  }

  const headerBytes: NGFBase64UrlResult = decodeBase64Url(parts[0]);
  if (!headerBytes.ok) {
    return NGFJwtDecodeResult.failBase64(JwtDecodeFailureCode.HEADER_BASE64, headerBytes, 3);
  }
  const payloadBytes: NGFBase64UrlResult = decodeBase64Url(parts[1]);
  if (!payloadBytes.ok) {
    return NGFJwtDecodeResult.failBase64(JwtDecodeFailureCode.PAYLOAD_BASE64, payloadBytes, 3);
  }

  const headerText: string = decodeUtf8(headerBytes.bytes);
  const payloadText: string = decodeUtf8(payloadBytes.bytes);

  const headerParsed: NGFJsonParseResult = parseJson(headerText);
  if (!headerParsed.ok || headerParsed.root === null) {
    return NGFJwtDecodeResult.failJson(JwtDecodeFailureCode.HEADER_JSON, headerParsed, 3);
  }
  const payloadParsed: NGFJsonParseResult = parseJson(payloadText);
  if (!payloadParsed.ok || payloadParsed.root === null) {
    return NGFJwtDecodeResult.failJson(JwtDecodeFailureCode.PAYLOAD_JSON, payloadParsed, 3);
  }

  const headerRoot: NGFJsonNode = headerParsed.root;
  const payloadRoot: NGFJsonNode = payloadParsed.root;
  const claims: NGFJwtClaim[] = [];
  const expText: string = findTopLevelNumberText(payloadRoot, 'exp');
  if (expText.length > 0) {
    claims.push(buildClaim('exp', expText, nowMilliseconds));
  }
  const nbfText: string = findTopLevelNumberText(payloadRoot, 'nbf');
  if (nbfText.length > 0) {
    claims.push(buildClaim('nbf', nbfText, nowMilliseconds));
  }
  const iatText: string = findTopLevelNumberText(payloadRoot, 'iat');
  if (iatText.length > 0) {
    claims.push(buildClaim('iat', iatText, nowMilliseconds));
  }

  const hasExpiration: boolean = expText.length > 0;
  let expired: boolean = false;
  if (hasExpiration) {
    const expSeconds: number = Number(expText);
    expired = !isNaN(expSeconds) && expSeconds * 1000 <= nowMilliseconds;
  }

  return new NGFJwtDecodeResult(true, JwtDecodeFailure.none(), 3, parts[0], parts[1], parts[2],
    formatJsonNode(headerRoot, 2), formatJsonNode(payloadRoot, 2),
    findTopLevelStringText(headerRoot, 'alg'), findTopLevelStringText(headerRoot, 'typ'),
    claims, hasExpiration, expired);
}