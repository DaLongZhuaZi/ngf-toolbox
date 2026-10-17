/**
 * 编解码套件的**纯逻辑层**。
 *
 * ## 为什么全部手写，不用现成的
 *
 * 平台与语言都提供了 Base64 / URL 编解码，但它们有两个共同问题：
 *
 * 1. 它们**不保证 UTF-8 正确**。很多实现的 Base64 是按「一个字符一个字节」做的
 *    （btoa 的做法），中文与 emoji 会在那里直接报错或产出乱码。本工具的输出
 *    必须是可互换的 UTF-8 字节序列，所以要自己把码点编成 UTF-8 字节。
 * 2. 它们**不告诉你哪里错了**。「解码失败」对排查问题毫无帮助；这里的每个
 *    解码函数都会指出是哪个字符、哪一段字节不合法。
 *
 * 另外，这些函数要能在 entry/src/test 里直接跑，所以本文件**不 import 任何**
 * ArkUI / @ohos.* 能力（连 @ohos.util 的 Base64Helper 都不能用）。
 *
 * ## 设计约定
 *
 * - 编码方向永不失败，返回字符串；解码方向可能失败，返回 {@link CodecResult}。
 * - 解码失败时 text 为空串、errorMessage 非空——**绝不**返回「尽力而为」的半截结果，
 *   因为静默乱码比一句报错更浪费时间。
 *
 * @module tools/codec-suite/CodecLogic
 */

/** 模式：一种编码格式 */
export enum CodecMode {
  BASE64 = 'base64',
  /** encodeURI 语义：保留 :/?#[]@!$&'()*+,;= 这些有语法含义的字符 */
  URL = 'url',
  /** encodeURIComponent 语义：把参数值里的保留字符也转义 */
  URL_COMPONENT = 'urlComponent',
  UNICODE = 'unicode',
  HEX = 'hex'
}

/** 方向 */
export enum CodecDirection {
  ENCODE = 'encode',
  DECODE = 'decode'
}

/** 编解码失败的原因码 */
export enum CodecFailureCode {
  NONE = 'none',
  EMPTY = 'empty',

  /** UTF-8：尾部被截断 */
  UTF8_TRUNCATED = 'utf8_truncated',
  /** UTF-8：续字节格式不对 */
  UTF8_BAD_CONTINUATION = 'utf8_bad_continuation',
  /** UTF-8：同一个码点用了多余的字节（过长编码） */
  UTF8_OVERLONG = 'utf8_overlong',
  /** UTF-8：代理区码点用三字节形式编码 */
  UTF8_SURROGATE = 'utf8_surrogate',
  /** UTF-8：码点超出 Unicode 范围 */
  UTF8_OUT_OF_RANGE = 'utf8_out_of_range',
  /** UTF-8：首字节不是合法起始字节 */
  UTF8_BAD_LEAD = 'utf8_bad_lead',

  B64_TOO_MANY_PAD = 'b64_too_many_pad',
  B64_PAD_NOT_AT_END = 'b64_pad_not_at_end',
  B64_BAD_CHAR = 'b64_bad_char',
  B64_LENGTH_MOD4 = 'b64_length_mod4',
  B64_PAD_MISMATCH = 'b64_pad_mismatch',
  B64_NOT_UTF8 = 'b64_not_utf8',

  PERCENT_INCOMPLETE = 'percent_incomplete',
  PERCENT_BAD = 'percent_bad',

  ESCAPE_TRAILING_BACKSLASH = 'escape_trailing_backslash',
  UNICODE_INCOMPLETE = 'unicode_incomplete',
  UNICODE_BAD_HEX = 'unicode_bad_hex',
  ESCAPE_UNSUPPORTED = 'escape_unsupported',

  HEX_BAD_CHAR = 'hex_bad_char',
  HEX_ODD_LENGTH = 'hex_odd_length',
  HEX_NOT_UTF8 = 'hex_not_utf8'
}

/**
 * 失败原因：码 + 参数（+ 可选的嵌套原因）。
 *
 * 需要「嵌套原因」是因为有两处失败其实是**下游的失败**：
 * 「Base64 能解开，但内容不是合法的 UTF-8」——外层说「解出来的字节不是文本」，
 * 内层说「字节哪里不合规」。压成一句 string 就没法翻译了：
 * 译文里前缀与内层句子的语序、标点都可能不同。
 */
export class CodecFailure {
  readonly code: CodecFailureCode;
  /** 资源文案的占位符参数 */
  readonly args: Array<string>;
  /** 嵌套的原因（没有时为 NONE） */
  readonly innerCode: CodecFailureCode;
  readonly innerArgs: Array<string>;

  constructor(code: CodecFailureCode, args: Array<string>,
    innerCode: CodecFailureCode, innerArgs: Array<string>) {
    this.code = code;
    this.args = args;
    this.innerCode = innerCode;
    this.innerArgs = innerArgs;
  }

  static none(): CodecFailure {
    return new CodecFailure(CodecFailureCode.NONE, [], CodecFailureCode.NONE, []);
  }

  static of(code: CodecFailureCode, args: Array<string>): CodecFailure {
    return new CodecFailure(code, args, CodecFailureCode.NONE, []);
  }

  static nested(code: CodecFailureCode, inner: CodecFailure): CodecFailure {
    return new CodecFailure(code, [], inner.code, inner.args);
  }
}

/** 编解码结果。成功时 ok=true 且 text 有值；失败时 text 为空串。 */
export class CodecResult {
  readonly ok: boolean;
  readonly text: string;
  /** 失败原因；成功时为 {@link CodecFailure.none}（**永不为 null**） */
  readonly failure: CodecFailure;

  constructor(ok: boolean, text: string, failure: CodecFailure) {
    this.ok = ok;
    this.text = text;
    this.failure = failure;
  }

  static success(text: string): CodecResult {
    return new CodecResult(true, text, CodecFailure.none());
  }

  static fail(failure: CodecFailure): CodecResult {
    return new CodecResult(false, '', failure);
  }
}

/** 字节序列解码结果（Base64 的中间层，暴露出来是为了能单测「字节级」行为） */
export class ByteResult {
  readonly ok: boolean;
  readonly bytes: Array<number>;
  readonly failure: CodecFailure;

  constructor(ok: boolean, bytes: Array<number>, failure: CodecFailure) {
    this.ok = ok;
    this.bytes = bytes;
    this.failure = failure;
  }

  static success(bytes: Array<number>): ByteResult {
    return new ByteResult(true, bytes, CodecFailure.none());
  }

  static fail(failure: CodecFailure): ByteResult {
    return new ByteResult(false, [], failure);
  }
}

function ok(text: string): CodecResult {
  return CodecResult.success(text);
}

/** 按码构造失败（参数顺序须与资源文案里的 %s 一致） */
function failCode(code: CodecFailureCode, args: Array<string>): CodecResult {
  return CodecResult.fail(CodecFailure.of(code, args));
}

const BASE64_ALPHABET: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
const HEX_DIGITS_LOWER: string = '0123456789abcdef';
const HEX_DIGITS_UPPER: string = '0123456789ABCDEF';

/** encodeURIComponent 不转义的字符（ECMAScript 规定的那一套） */
const URL_COMPONENT_SAFE: string = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()";
/** encodeURI 额外保留的保留字符（它们在 URL 里有语法含义） */
const URL_RESERVED: string = ';/?:@&=+$,#';

/** 十六进制字符 → 数值；不是十六进制返回 -1 */
export function hexValue(ch: string): number {
  if (ch >= '0' && ch <= '9') {
    return ch.charCodeAt(0) - 48;
  }
  if (ch >= 'a' && ch <= 'f') {
    return ch.charCodeAt(0) - 87;
  }
  if (ch >= 'A' && ch <= 'F') {
    return ch.charCodeAt(0) - 55;
  }
  return -1;
}

/** 一个字节 → 两位十六进制 */
export function byteToHex(value: number, uppercase: boolean): string {
  const table: string = uppercase ? HEX_DIGITS_UPPER : HEX_DIGITS_LOWER;
  const high: number = (value >> 4) & 0x0F;
  const low: number = value & 0x0F;
  return table.charAt(high) + table.charAt(low);
}

function isHexDigits(text: string): boolean {
  if (text.length === 0) {
    return false;
  }
  for (let i: number = 0; i < text.length; i++) {
    if (hexValue(text.charAt(i)) < 0) {
      return false;
    }
  }
  return true;
}

/**
 * 把字符串编成 UTF-8 字节。
 *
 * 代理对（emoji）必须合成一个码点再编码，否则会编出两段「孤立代理」字节，
 * 解回来就是两个问号——这是编解码工具最常见的翻车点。
 * 单独出现的代理（半个 emoji）无法编码，按 Unicode 的替换字符 U+FFFD 处理，
 * 而不是抛异常：用户可能只是粘漏了一个字符。
 */
export function utf8BytesOf(text: string): Array<number> {
  const bytes: Array<number> = [];
  let i: number = 0;
  while (i < text.length) {
    let code: number = text.charCodeAt(i);
    let size: number = 1;
    if (code >= 0xD800 && code <= 0xDBFF) {
      const next: number = i + 1 < text.length ? text.charCodeAt(i + 1) : 0;
      if (next >= 0xDC00 && next <= 0xDFFF) {
        code = 0x10000 + (code - 0xD800) * 0x400 + (next - 0xDC00);
        size = 2;
      } else {
        code = 0xFFFD;
      }
    } else if (code >= 0xDC00 && code <= 0xDFFF) {
      code = 0xFFFD;
    }
    if (code <= 0x7F) {
      bytes.push(code);
    } else if (code <= 0x7FF) {
      bytes.push(0xC0 | (code >> 6));
      bytes.push(0x80 | (code & 0x3F));
    } else if (code <= 0xFFFF) {
      bytes.push(0xE0 | (code >> 12));
      bytes.push(0x80 | ((code >> 6) & 0x3F));
      bytes.push(0x80 | (code & 0x3F));
    } else {
      bytes.push(0xF0 | (code >> 18));
      bytes.push(0x80 | ((code >> 12) & 0x3F));
      bytes.push(0x80 | ((code >> 6) & 0x3F));
      bytes.push(0x80 | (code & 0x3F));
    }
    i = i + size;
  }
  return bytes;
}

/**
 * 把 UTF-8 字节解回字符串。
 *
 * 严格校验：过长编码（overlong）、代理区码点、越界码点、被截断的序列
 * 一律报错。宽松地「尽力解码」会产出看起来正常、实际已经损坏的文本，
 * 那种结果比报错危险得多。
 */
export function utf8TextOf(bytes: Array<number>): CodecResult {
  let out: string = '';
  let i: number = 0;
  while (i < bytes.length) {
    const b0: number = bytes[i];
    if (b0 <= 0x7F) {
      out = out + String.fromCharCode(b0);
      i = i + 1;
      continue;
    }
    if (b0 >= 0xC2 && b0 <= 0xDF) {
      if (i + 1 >= bytes.length) {
        return failCode(CodecFailureCode.UTF8_TRUNCATED, []);
      }
      const b1: number = bytes[i + 1];
      if ((b1 & 0xC0) !== 0x80) {
        return failCode(CodecFailureCode.UTF8_BAD_CONTINUATION, []);
      }
      out = out + String.fromCharCode(((b0 & 0x1F) << 6) | (b1 & 0x3F));
      i = i + 2;
      continue;
    }
    if (b0 >= 0xE0 && b0 <= 0xEF) {
      if (i + 2 >= bytes.length) {
        return failCode(CodecFailureCode.UTF8_TRUNCATED, []);
      }
      const b1: number = bytes[i + 1];
      const b2: number = bytes[i + 2];
      if ((b1 & 0xC0) !== 0x80 || (b2 & 0xC0) !== 0x80) {
        return failCode(CodecFailureCode.UTF8_BAD_CONTINUATION, []);
      }
      const code: number = ((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F);
      if (code < 0x800) {
        return failCode(CodecFailureCode.UTF8_OVERLONG, []);
      }
      if (code >= 0xD800 && code <= 0xDFFF) {
        return failCode(CodecFailureCode.UTF8_SURROGATE, []);
      }
      out = out + String.fromCharCode(code);
      i = i + 3;
      continue;
    }
    if (b0 >= 0xF0 && b0 <= 0xF4) {
      if (i + 3 >= bytes.length) {
        return failCode(CodecFailureCode.UTF8_TRUNCATED, []);
      }
      const b1: number = bytes[i + 1];
      const b2: number = bytes[i + 2];
      const b3: number = bytes[i + 3];
      if ((b1 & 0xC0) !== 0x80 || (b2 & 0xC0) !== 0x80 || (b3 & 0xC0) !== 0x80) {
        return failCode(CodecFailureCode.UTF8_BAD_CONTINUATION, []);
      }
      const code: number = ((b0 & 0x07) << 18) | ((b1 & 0x3F) << 12) | ((b2 & 0x3F) << 6) | (b3 & 0x3F);
      if (code < 0x10000 || code > 0x10FFFF) {
        return failCode(CodecFailureCode.UTF8_OUT_OF_RANGE, []);
      }
      const adjusted: number = code - 0x10000;
      out = out + String.fromCharCode(0xD800 + (adjusted >> 10), 0xDC00 + (adjusted & 0x3FF));
      i = i + 4;
      continue;
    }
    return failCode(CodecFailureCode.UTF8_BAD_LEAD, [byteToHex(b0, true)]);
  }
  return ok(out);
}

// ── Base64 ────────────────────────────────────────────────

/** 字节序列 → 标准 Base64（带 = 补齐） */
export function base64EncodeBytes(bytes: Array<number>): string {
  let out: string = '';
  let i: number = 0;
  while (i < bytes.length) {
    const b0: number = bytes[i];
    const hasSecond: boolean = i + 1 < bytes.length;
    const hasThird: boolean = i + 2 < bytes.length;
    const b1: number = hasSecond ? bytes[i + 1] : 0;
    const b2: number = hasThird ? bytes[i + 2] : 0;
    out = out + BASE64_ALPHABET.charAt(b0 >> 2);
    out = out + BASE64_ALPHABET.charAt(((b0 & 0x03) << 4) | (b1 >> 4));
    out = out + (hasSecond ? BASE64_ALPHABET.charAt(((b1 & 0x0F) << 2) | (b2 >> 6)) : '=');
    out = out + (hasThird ? BASE64_ALPHABET.charAt(b2 & 0x3F) : '=');
    i = i + 3;
  }
  return out;
}

/**
 * Base64 → 字节序列。
 *
 * 宽容与严格的边界：
 * - 允许换行与空格（被折行包裹的 Base64 太常见了）
 * - 允许**缺少** = 补齐（很多地方传不带补齐的串）
 * - 但不允许 = 出现在中间、不允许 = 的个数与内容长度自相矛盾、
 *   不允许出现字母表之外的字符、不允许长度模 4 余 1（那组不出字节）
 */
export function base64DecodeBytes(text: string): ByteResult {
  let cleaned: string = '';
  for (let i: number = 0; i < text.length; i++) {
    const ch: string = text.charAt(i);
    if (ch === ' ' || ch === '\n' || ch === '\r' || ch === '\t') {
      continue;
    }
    cleaned = cleaned + ch;
  }
  if (cleaned.length === 0) {
    return ByteResult.success([]);
  }
  let padding: number = 0;
  let body: string = cleaned;
  while (body.length > 0 && body.charAt(body.length - 1) === '=') {
    padding++;
    body = body.substring(0, body.length - 1);
  }
  if (padding > 2) {
    return ByteResult.fail(CodecFailure.of(CodecFailureCode.B64_TOO_MANY_PAD, []));
  }
  if (body.indexOf('=') >= 0) {
    return ByteResult.fail(CodecFailure.of(CodecFailureCode.B64_PAD_NOT_AT_END, []));
  }
  const values: Array<number> = [];
  for (let i: number = 0; i < body.length; i++) {
    const ch: string = body.charAt(i);
    const index: number = BASE64_ALPHABET.indexOf(ch);
    if (index < 0) {
      return ByteResult.fail(CodecFailure.of(CodecFailureCode.B64_BAD_CHAR, [ch]));
    }
    values.push(index);
  }
  const remainder: number = values.length % 4;
  if (remainder === 1) {
    return ByteResult.fail(CodecFailure.of(CodecFailureCode.B64_LENGTH_MOD4, []));
  }
  if (padding > 0) {
    const expected: number = remainder === 2 ? 2 : (remainder === 3 ? 1 : 0);
    if (padding !== expected) {
      return ByteResult.fail(CodecFailure.of(CodecFailureCode.B64_PAD_MISMATCH, []));
    }
  }
  const bytes: Array<number> = [];
  let i: number = 0;
  while (i < values.length) {
    const remaining: number = values.length - i;
    const v0: number = values[i];
    const v1: number = remaining > 1 ? values[i + 1] : 0;
    const v2: number = remaining > 2 ? values[i + 2] : 0;
    const v3: number = remaining > 3 ? values[i + 3] : 0;
    bytes.push(((v0 << 2) | (v1 >> 4)) & 0xFF);
    if (remaining > 2) {
      bytes.push((((v1 & 0x0F) << 4) | (v2 >> 2)) & 0xFF);
    }
    if (remaining > 3) {
      bytes.push((((v2 & 0x03) << 6) | v3) & 0xFF);
    }
    i = i + 4;
  }
  return ByteResult.success(bytes);
}

/** 文本 → Base64 字符串 */
export function encodeBase64(text: string): CodecResult {
  return ok(base64EncodeBytes(utf8BytesOf(text)));
}

/** Base64 字符串 → 文本（解码结果必须是合法 UTF-8，否则报错） */
export function decodeBase64(text: string): CodecResult {
  const decoded: ByteResult = base64DecodeBytes(text);
  if (!decoded.ok) {
    return CodecResult.fail(decoded.failure);
  }
  const restored: CodecResult = utf8TextOf(decoded.bytes);
  if (!restored.ok) {
    return CodecResult.fail(CodecFailure.nested(CodecFailureCode.B64_NOT_UTF8, restored.failure));
  }
  return restored;
}

// ── URL 百分号编码 ────────────────────────────────────────

/** 把一个字符（可能是代理对的两个 code unit）按 UTF-8 逐字节转义 */
function percentEncodeChar(ch: string): string {
  const bytes: Array<number> = utf8BytesOf(ch);
  let out: string = '';
  for (let i: number = 0; i < bytes.length; i++) {
    out = out + '%' + byteToHex(bytes[i], true);
  }
  return out;
}

function percentEncode(text: string, safe: string): string {
  let out: string = '';
  let i: number = 0;
  while (i < text.length) {
    const ch: string = text.charAt(i);
    if (safe.indexOf(ch) >= 0) {
      out = out + ch;
      i = i + 1;
      continue;
    }
    const code: number = text.charCodeAt(i);
    if (code >= 0xD800 && code <= 0xDBFF && i + 1 < text.length) {
      const next: number = text.charCodeAt(i + 1);
      if (next >= 0xDC00 && next <= 0xDFFF) {
        out = out + percentEncodeChar(text.substring(i, i + 2));
        i = i + 2;
        continue;
      }
    }
    out = out + percentEncodeChar(ch);
    i = i + 1;
  }
  return out;
}

/**
 * encodeURIComponent 语义：把参数值里的保留字符也转义。
 *
 * 不转义的只有 A-Z a-z 0-9 与 - _ . ! ~ * ' ( )。
 * 注意空格编成 %20 而**不是** +（+ 是表单编码 form-urlencoded 的口径，
 * 两套口径混用会在后端解出错误的值）。
 */
export function encodeUrlComponent(text: string): string {
  return percentEncode(text, URL_COMPONENT_SAFE);
}

/**
 * encodeURI 语义：保留 :/?#[]@!$&'()*+,;= 这些在 URL 里有语法含义的字符。
 *
 * 用它整段处理一个 URL；处理参数值时请用 {@link encodeUrlComponent}，
 * 否则参数里的 & 与 = 不会被转义，会把查询串拆坏。
 */
export function encodeUrl(text: string): string {
  return percentEncode(text, URL_COMPONENT_SAFE + URL_RESERVED);
}

/**
 * 百分号解码（encodeURI 与 encodeURIComponent 的解码是同一个操作）。
 *
 * 未被转义的字符同样参与解码：它们先按 UTF-8 编成字节再统一还原，
 * 这样「一半转义一半没转义」的输入也能得到正确结果。
 * 注意 + 保持为 +（不当作空格），理由同上：那是表单编码的口径。
 */
export function decodeUrlComponent(text: string): CodecResult {
  const bytes: Array<number> = [];
  let i: number = 0;
  while (i < text.length) {
    const ch: string = text.charAt(i);
    if (ch === '%') {
      if (i + 2 >= text.length) {
        return failCode(CodecFailureCode.PERCENT_INCOMPLETE, []);
      }
      const high: number = hexValue(text.charAt(i + 1));
      const low: number = hexValue(text.charAt(i + 2));
      if (high < 0 || low < 0) {
        return failCode(CodecFailureCode.PERCENT_BAD, [text.substring(i + 1, i + 3)]);
      }
      bytes.push(high * 16 + low);
      i = i + 3;
      continue;
    }
    const code: number = text.charCodeAt(i);
    if (code >= 0xD800 && code <= 0xDBFF && i + 1 < text.length) {
      const next: number = text.charCodeAt(i + 1);
      if (next >= 0xDC00 && next <= 0xDFFF) {
        const pair: Array<number> = utf8BytesOf(text.substring(i, i + 2));
        for (let k: number = 0; k < pair.length; k++) {
          bytes.push(pair[k]);
        }
        i = i + 2;
        continue;
      }
    }
    const single: Array<number> = utf8BytesOf(ch);
    for (let k: number = 0; k < single.length; k++) {
      bytes.push(single[k]);
    }
    i = i + 1;
  }
  return utf8TextOf(bytes);
}

// ── Unicode 转义 ──────────────────────────────────────────

/**
 * 把非 ASCII 字符转成 \\uXXXX 写法。
 *
 * 可打印 ASCII 原样保留：把整段中文转义成 \\u4E2D\\u6587 虽然合法，
 * 但人已经读不出内容了，而「看得懂」正是用户打开这个工具的目的。
 * 反斜杠会转义成 \\\\，所以 {@link unescapeUnicode} 可以精确还原。
 */
export function escapeUnicode(text: string): string {
  let out: string = '';
  for (let i: number = 0; i < text.length; i++) {
    const ch: string = text.charAt(i);
    const code: number = text.charCodeAt(i);
    if (ch === '\\') {
      out = out + '\\\\';
      continue;
    }
    if (code >= 0x20 && code <= 0x7E) {
      out = out + ch;
      continue;
    }
    out = out + '\\u' + byteToHex((code >> 8) & 0xFF, true) + byteToHex(code & 0xFF, true);
  }
  return out;
}

/**
 * \\uXXXX 反转义。
 *
 * 同时接受 JS 字符串里常见的 \\n \\t \\r \\b \\f \\" \\' \\/ 与 \\\\，
 * 因为用户粘进来的多半是一段 JS 字面量，而不是只有 \\uXXXX 的纯转义串。
 * 不支持的转义一律报错，不做「原样保留」——那会掩盖真正的输入错误。
 */
export function unescapeUnicode(text: string): CodecResult {
  let out: string = '';
  let i: number = 0;
  while (i < text.length) {
    const ch: string = text.charAt(i);
    if (ch !== '\\') {
      out = out + ch;
      i = i + 1;
      continue;
    }
    if (i + 1 >= text.length) {
      return failCode(CodecFailureCode.ESCAPE_TRAILING_BACKSLASH, []);
    }
    const marker: string = text.charAt(i + 1);
    if (marker === '\\') {
      out = out + '\\';
      i = i + 2;
      continue;
    }
    if (marker === 'n') {
      out = out + '\n';
      i = i + 2;
      continue;
    }
    if (marker === 't') {
      out = out + '\t';
      i = i + 2;
      continue;
    }
    if (marker === 'r') {
      out = out + '\r';
      i = i + 2;
      continue;
    }
    if (marker === 'b') {
      out = out + '\b';
      i = i + 2;
      continue;
    }
    if (marker === 'f') {
      out = out + '\f';
      i = i + 2;
      continue;
    }
    if (marker === '"' || marker === "'" || marker === '/') {
      out = out + marker;
      i = i + 2;
      continue;
    }
    if (marker === 'u') {
      if (i + 6 > text.length) {
        return failCode(CodecFailureCode.UNICODE_INCOMPLETE, []);
      }
      const four: string = text.substring(i + 2, i + 6);
      if (!isHexDigits(four)) {
        return failCode(CodecFailureCode.UNICODE_BAD_HEX, [four]);
      }
      let code: number = 0;
      for (let k: number = 0; k < 4; k++) {
        code = code * 16 + hexValue(text.charAt(i + 2 + k));
      }
      out = out + String.fromCharCode(code);
      i = i + 6;
      continue;
    }
    return failCode(CodecFailureCode.ESCAPE_UNSUPPORTED, [marker]);
  }
  return ok(out);
}

// ── 十六进制 ──────────────────────────────────────────────

/** 文本 → UTF-8 字节的十六进制写法；separator 可以是空串、空格、冒号等 */
export function encodeHex(text: string, uppercase: boolean, separator: string): string {
  const bytes: Array<number> = utf8BytesOf(text);
  const parts: Array<string> = [];
  for (let i: number = 0; i < bytes.length; i++) {
    parts.push(byteToHex(bytes[i], uppercase));
  }
  return parts.join(separator);
}

/**
 * 十六进制 → 文本。
 *
 * 允许空格、冒号、短横线、逗号与 0x 前缀作为分组写法（从日志/调试器里粘出来的
 * 十六进制通常带这些），但**字节数必须是偶数**：奇数个十六进制字符凑不出字节，
 * 与其猜「是不是漏了一位」不如直接报错。
 */
export function decodeHex(text: string): CodecResult {
  let cleaned: string = '';
  for (let i: number = 0; i < text.length; i++) {
    const ch: string = text.charAt(i);
    if (ch === ' ' || ch === '\n' || ch === '\r' || ch === '\t' || ch === ':' || ch === '-' || ch === ',') {
      continue;
    }
    cleaned = cleaned + ch;
  }
  cleaned = cleaned.split('0x').join('').split('0X').join('');
  if (cleaned.length === 0) {
    return ok('');
  }
  for (let i: number = 0; i < cleaned.length; i++) {
    const ch: string = cleaned.charAt(i);
    if (hexValue(ch) < 0) {
      return failCode(CodecFailureCode.HEX_BAD_CHAR, [ch]);
    }
  }
  if (cleaned.length % 2 !== 0) {
    return failCode(CodecFailureCode.HEX_ODD_LENGTH, [String(cleaned.length)]);
  }
  const bytes: Array<number> = [];
  for (let i: number = 0; i < cleaned.length; i = i + 2) {
    bytes.push(hexValue(cleaned.charAt(i)) * 16 + hexValue(cleaned.charAt(i + 1)));
  }
  const restored: CodecResult = utf8TextOf(bytes);
  if (!restored.ok) {
    return CodecResult.fail(CodecFailure.nested(CodecFailureCode.HEX_NOT_UTF8, restored.failure));
  }
  return restored;
}

// ── 统一入口 ──────────────────────────────────────────────

/** 全部模式（页面按这个顺序渲染选择器） */
export function codecModes(): Array<CodecMode> {
  const list: Array<CodecMode> = [];
  list.push(CodecMode.BASE64);
  list.push(CodecMode.URL);
  list.push(CodecMode.URL_COMPONENT);
  list.push(CodecMode.UNICODE);
  list.push(CodecMode.HEX);
  return list;
}

// codecModeLabel / codecModeHint 已搬到 UI 层（CodecMessages.ets）。
//
// 它们返回的是给用户看的**文案**（「URL 整段」「按 UTF-8 字节做标准 Base64」），
// 而纯逻辑层不能 import ArkUI 的 $r()。模式本身仍然是这边的 CodecMode 枚举——
// 枚举值是稳定的英文标识，本来就不该翻译。

/**
 * 统一入口。
 *
 * 空输入直接返回错误而不是空结果：页面此时应该提示「请输入内容」，
 * 而不是显示一个空白输出让用户怀疑工具是不是坏了。
 */
export function runCodec(mode: CodecMode, direction: CodecDirection, input: string): CodecResult {
  if (input.length === 0) {
    return failCode(CodecFailureCode.EMPTY, []);
  }
  if (mode === CodecMode.BASE64) {
    return direction === CodecDirection.ENCODE ? encodeBase64(input) : decodeBase64(input);
  }
  if (mode === CodecMode.URL) {
    return direction === CodecDirection.ENCODE ? ok(encodeUrl(input)) : decodeUrlComponent(input);
  }
  if (mode === CodecMode.URL_COMPONENT) {
    return direction === CodecDirection.ENCODE ? ok(encodeUrlComponent(input)) : decodeUrlComponent(input);
  }
  if (mode === CodecMode.UNICODE) {
    return direction === CodecDirection.ENCODE ? ok(escapeUnicode(input)) : unescapeUnicode(input);
  }
  if (direction === CodecDirection.ENCODE) {
    return ok(encodeHex(input, false, ' '));
  }
  return decodeHex(input);
}