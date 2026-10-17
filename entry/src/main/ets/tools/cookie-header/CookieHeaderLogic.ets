/**
 * Cookie 头解析的纯逻辑实现。
 *
 * ## 两个方向
 *
 * 请求侧：k=v; k2=v2 拆成键值对（值不 URL 解码，原样展示）。
 * 响应侧：Set-Cookie 单条解析出键、值与常用属性。
 *
 * @module tools/cookie-header/CookieHeaderLogic
 */

/** 失败原因码 */
export enum CookieFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input'
}
/** 一次失败的原因与文案参数 */
export class CookieFailure {
  readonly code: CookieFailureCode;
  readonly args: Array<string>;

  constructor(code: CookieFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}
/** 请求侧的一个键值对 */
export class CookiePair {
  readonly name: string;
  readonly value: string;

  constructor(name: string, value: string) {
    this.name = name;
    this.value = value;
  }
}

/** 请求侧结果 */
export class CookieListResult {
  readonly ok: boolean;
  readonly failure: CookieFailure;
  readonly pairs: Array<CookiePair>;

  constructor(ok: boolean, failure: CookieFailure, pairs: Array<CookiePair>) {
    this.ok = ok;
    this.failure = failure;
    this.pairs = pairs;
  }
}

const SEMI: string = String.fromCharCode(59);
const EQ: string = String.fromCharCode(61);

/** 请求侧：Cookie 头拆键值对 */
export function parseCookieHeader(input: string): CookieListResult {
  if (input.trim().length === 0) {
    return new CookieListResult(false, new CookieFailure(CookieFailureCode.EMPTY_INPUT, []), []);
  }
  const parts: Array<string> = input.split(SEMI);
  const pairs: Array<CookiePair> = [];
  for (let i = 0; i < parts.length; i++) {
    const seg: string = parts[i].trim();
    if (seg.length === 0) {
      continue;
    }
    const eq: number = seg.indexOf(EQ);
    if (eq < 0) {
      pairs.push(new CookiePair(seg, ''));
    } else {
      pairs.push(new CookiePair(seg.substring(0, eq).trim(), seg.substring(eq + 1).trim()));
    }
  }
  return new CookieListResult(true, new CookieFailure(CookieFailureCode.NONE, []), pairs);
}
/** Set-Cookie 解析结果 */
export class SetCookieResult {
  readonly ok: boolean;
  readonly failure: CookieFailure;
  readonly name: string;
  readonly value: string;
  /** 属性表：属性名（小写）到值的映射，布尔属性值为空串 */
  readonly attrs: Map<string, string>;

  constructor(ok: boolean, failure: CookieFailure, name: string, value: string,
    attrs: Map<string, string>) {
    this.ok = ok;
    this.failure = failure;
    this.name = name;
    this.value = value;
    this.attrs = attrs;
  }
}

/** 响应侧：Set-Cookie 单条解析 */
export function parseSetCookie(input: string): SetCookieResult {
  if (input.trim().length === 0) {
    return new SetCookieResult(false, new CookieFailure(CookieFailureCode.EMPTY_INPUT, []), '', '', new Map<string, string>());
  }
  const parts: Array<string> = input.split(SEMI);
  const nv: string = parts[0].trim();
  const eq: number = nv.indexOf(EQ);
  const name: string = eq < 0 ? nv : nv.substring(0, eq).trim();
  const value: string = eq < 0 ? '' : nv.substring(eq + 1).trim();
  const attrs: Map<string, string> = new Map<string, string>();
  for (let i = 1; i < parts.length; i++) {
    const a: string = parts[i].trim();
    if (a.length === 0) {
      continue;
    }
    const aeq: number = a.indexOf(EQ);
    if (aeq < 0) {
      attrs.set(a.toLowerCase(), '');
    } else {
      attrs.set(a.substring(0, aeq).trim().toLowerCase(), a.substring(aeq + 1).trim());
    }
  }
  return new SetCookieResult(true, new CookieFailure(CookieFailureCode.NONE, []), name, value, attrs);
}