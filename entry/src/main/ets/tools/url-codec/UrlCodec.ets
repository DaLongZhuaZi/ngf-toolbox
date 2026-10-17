/**
 * URL 编解码的纯逻辑实现。
 *
 * ## 拆两层的原因
 *
 * encodeURIComponent 只回答「整体编码后的串长什么样」，但开发者排查 URL 问题时
 * 真正要看的是**每个参数各自是什么**：哪个值里的 & 被编码了、哪个 + 是空格。
 * 所以这里把「整串编解码」与「query 逐参数拆解」分开，后者用 & 与 = 切分
 * （先按 & 切、再在**每段内**找第一个 = ——值里出现编码后的 %3D 不会被误切）。
 *
 * ## + 号的语义
 *
 * `+` 在 application/x-www-form-urlencoded 里是空格，但在 RFC 3986 里是合法字面量。
 * 解码时**默认按空格解释**（浏览器地址栏与表单的实际行为），同时把「不含 + 的原样」
 * 也给出来，两个都展示，不替用户猜。
 *
 * @module tools/url-codec/UrlCodec
 */

/** 失败原因码（纯逻辑不产文案，见 RadixConvert.ets 同款切分的说明） */
export enum UrlCodecFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  /** decodeURIComponent 抛出的 URIError（畸形 % 序列） */
  MALFORMED_ESCAPE = 'malformed_escape',
  /** 参数段没有 =（无值参数按空串处理不报错，但**整段为空白**时报这个） */
  NOT_A_PAIR = 'not_a_pair'
}

/** 一次失败的原因与文案参数（顺序与资源里 %s 的出现顺序一致） */
export class UrlCodecFailure {
  readonly code: UrlCodecFailureCode;
  readonly args: Array<string>;

  constructor(code: UrlCodecFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 单个 query 参数的拆解结果 */
export class UrlQueryPart {
  /** 原样（未解码）的键 */
  readonly rawKey: string;
  /** 原样（未解码）的值；无值参数为空串 */
  readonly rawValue: string;
  /** 解码后的键（+ 按空格） */
  readonly key: string;
  /** 解码后的值（+ 按空格） */
  readonly value: string;
  /** 解码后的值（+ 保留原样，RFC 3986 口径） */
  readonly valuePlusLiteral: string;
  /** 是否是无值参数（只有 key 没有 =） */
  readonly valueless: boolean;

  constructor(rawKey: string, rawValue: string, key: string, value: string,
    valuePlusLiteral: string, valueless: boolean) {
    this.rawKey = rawKey;
    this.rawValue = rawValue;
    this.key = key;
    this.value = value;
    this.valuePlusLiteral = valuePlusLiteral;
    this.valueless = valueless;
  }
}

/** query 拆解结果 */
export class UrlQueryParseResult {
  readonly ok: boolean;
  readonly failure: UrlCodecFailure;
  readonly parts: Array<UrlQueryPart>;

  constructor(ok: boolean, failure: UrlCodecFailure, parts: Array<UrlQueryPart>) {
    this.ok = ok;
    this.failure = failure;
    this.parts = parts;
  }
}

function decodeComponentLenient(input: string, plusAsSpace: boolean): string {
  let out: string = input;
  if (plusAsSpace) {
    // 只把裸的 + 换成空格；%2B 表示的字面加号不受影响
    out = out.split('+').join(' ');
  }
  return out;
}

/**
 * 对一段「已编码文本」做解码。
 * 返回串本身；畸形 % 序列（如 %E4%B8%）时返回失败。
 */
export function decodeUrlText(input: string): UrlCodecParseTextResult {
  return decodeTextInternal(input, true);
}

/** 解码并保留 + 号（RFC 3986 口径），供与表单口径并排展示 */
export function decodeUrlTextLiteral(input: string): UrlCodecParseTextResult {
  return decodeTextInternal(input, false);
}

/** 文本解码结果 */
export class UrlCodecParseTextResult {
  readonly ok: boolean;
  readonly failure: UrlCodecFailure;
  readonly text: string;

  constructor(ok: boolean, failure: UrlCodecFailure, text: string) {
    this.ok = ok;
    this.failure = failure;
    this.text = text;
  }
}

function decodeTextInternal(input: string, plusAsSpace: boolean): UrlCodecParseTextResult {
  const text: string = input.trim();
  if (text.length === 0) {
    return new UrlCodecParseTextResult(false, new UrlCodecFailure(UrlCodecFailureCode.EMPTY_INPUT, []), '');
  }
  let decoded: string = '';
  try {
    decoded = decodeURIComponent(plusAsSpace ? decodeComponentLenient(text, true) : text);
  } catch (e) {
    return new UrlCodecParseTextResult(false,
      new UrlCodecFailure(UrlCodecFailureCode.MALFORMED_ESCAPE, []), '');
  }
  return new UrlCodecParseTextResult(true, new UrlCodecFailure(UrlCodecFailureCode.NONE, []), decoded);
}

/** 编码一段文本（encodeURIComponent 口径；空格成 %20） */
export function encodeUrlText(input: string): string {
  return encodeURIComponent(input);
}

/**
 * 把 query 串（可带 ? 前缀）拆成逐参数列表。
 * 空串/纯 ? 返回空列表（不是失败——空 query 是合法状态）。
 */
export function parseUrlQuery(input: string): UrlQueryParseResult {
  let text: string = input.trim();
  if (text.length === 0) {
    return new UrlQueryParseResult(true, new UrlCodecFailure(UrlCodecFailureCode.NONE, []), []);
  }
  if (text.charAt(0) === '?') {
    text = text.substring(1);
  }
  if (text.length === 0) {
    return new UrlQueryParseResult(true, new UrlCodecFailure(UrlCodecFailureCode.NONE, []), []);
  }
  const rawParts: Array<string> = text.split('&');
  const parts: Array<UrlQueryPart> = [];
  for (let i = 0; i < rawParts.length; i++) {
    const seg: string = rawParts[i];
    if (seg.trim().length === 0) {
      // a=1&&b=2 这类空段：宽容跳过而不是报错（浏览器行为一致）
      continue;
    }
    const eq: number = seg.indexOf('=');
    const valueless: boolean = eq < 0;
    const rawKey: string = valueless ? seg : seg.substring(0, eq);
    const rawValue: string = valueless ? '' : seg.substring(eq + 1);
    let key: string = rawKey;
    let value: string = rawValue;
    let valuePlusLiteral: string = rawValue;
    try {
      key = decodeURIComponent(decodeComponentLenient(rawKey, true));
      value = decodeURIComponent(decodeComponentLenient(rawValue, true));
      valuePlusLiteral = decodeURIComponent(rawValue);
    } catch (e) {
      return new UrlQueryParseResult(false,
        new UrlCodecFailure(UrlCodecFailureCode.MALFORMED_ESCAPE, [String(i + 1)]), []);
    }
    parts.push(new UrlQueryPart(rawKey, rawValue, key, value, valuePlusLiteral, valueless));
  }
  return new UrlQueryParseResult(true, new UrlCodecFailure(UrlCodecFailureCode.NONE, []), parts);
}
