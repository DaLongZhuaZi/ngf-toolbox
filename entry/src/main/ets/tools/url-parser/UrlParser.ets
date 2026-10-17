/**
 * URL 解析器的纯逻辑实现。
 *
 * ## 用「手写解析」而不是 new URL()
 *
 * ArkTS 运行器的 URL API 是设备能力（@kit），纯逻辑不能 import。
 * 手写解析规则：scheme://userinfo@host:port/path?query#fragment
 * 各段按定界符切分，端口默认值按 scheme 补（http=80, https=443）。
 *
 * ## 不支持的（limitation 会写明）
 *
 * 不做 IDN（国际化域名）转码，不校验 host 的合法性（只做结构拆分），
 * 相对 URL（无 scheme）报错。
 *
 * @module tools/url-parser/UrlParser
 */

/** 失败原因码 */
export enum UrlParseFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  /** 没有 scheme:// 前缀（相对 URL 不支持） */
  NO_SCHEME = 'no_scheme',
  /** scheme 后没有 //（如 mailto:） */
  BAD_SYNTAX = 'bad_syntax',
  /** 缺少 host */
  NO_HOST = 'no_host'
}

/** 一次失败的原因与文案参数 */
export class UrlParseFailure {
  readonly code: UrlParseFailureCode;
  readonly args: Array<string>;

  constructor(code: UrlParseFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 查询参数键值对 */
export class UrlQueryPair {
  readonly rawKey: string;
  readonly rawValue: string;
  readonly key: string;
  readonly value: string;

  constructor(rawKey: string, rawValue: string, key: string, value: string) {
    this.rawKey = rawKey;
    this.rawValue = rawValue;
    this.key = key;
    this.value = value;
  }
}

/** 解析结果 */
export class UrlParseResult {
  readonly ok: boolean;
  readonly failure: UrlParseFailure;
  readonly scheme: string;
  readonly userinfo: string;
  readonly host: string;
  readonly port: string;
  /** 含默认端口（http=80, https=443） */
  readonly effectivePort: string;
  readonly path: string;
  readonly query: string;
  readonly fragment: string;
  readonly queryPairs: Array<UrlQueryPair>;

  constructor(ok: boolean, failure: UrlParseFailure, scheme: string, userinfo: string,
    host: string, port: string, effectivePort: string, path: string,
    query: string, fragment: string, queryPairs: Array<UrlQueryPair>) {
    this.ok = ok;
    this.failure = failure;
    this.scheme = scheme;
    this.userinfo = userinfo;
    this.host = host;
    this.port = port;
    this.effectivePort = effectivePort;
    this.path = path;
    this.query = query;
    this.fragment = fragment;
    this.queryPairs = queryPairs;
  }
}

function decodeURIComponentSafe(text: string): string {
  try {
    return decodeURIComponent(text);
  } catch (e) {
    return text;
  }
}

/** 主入口 */
export function parseUrl(input: string): UrlParseResult {
  const fail = (code: UrlParseFailureCode): UrlParseResult =>
    new UrlParseResult(false, new UrlParseFailure(code, []), '', '', '', '', '', '', '', '', []);
  const text: string = input.trim();
  if (text.length === 0) {
    return fail(UrlParseFailureCode.EMPTY_INPUT);
  }
  // scheme://
  const schemeEnd: number = text.indexOf('://');
  if (schemeEnd < 0) {
    return fail(UrlParseFailureCode.NO_SCHEME);
  }
  const scheme: string = text.substring(0, schemeEnd).toLowerCase();
  if (scheme.length === 0) {
    return fail(UrlParseFailureCode.NO_SCHEME);
  }
  let rest: string = text.substring(schemeEnd + 3);
  // fragment
  let fragment: string = '';
  const fragIdx: number = rest.indexOf('#');
  if (fragIdx >= 0) {
    fragment = rest.substring(fragIdx + 1);
    rest = rest.substring(0, fragIdx);
  }
  // query
  let query: string = '';
  const queryIdx: number = rest.indexOf('?');
  if (queryIdx >= 0) {
    query = rest.substring(queryIdx + 1);
    rest = rest.substring(0, queryIdx);
  }
  // userinfo
  let userinfo: string = '';
  const atIdx: number = rest.lastIndexOf('@');
  if (atIdx > 0 && atIdx < rest.indexOf('/')) {
    userinfo = rest.substring(0, atIdx);
    rest = rest.substring(atIdx + 1);
  }
  // path
  let path: string = '';
  const pathIdx: number = rest.indexOf('/');
  if (pathIdx >= 0) {
    path = rest.substring(pathIdx);
    rest = rest.substring(0, pathIdx);
  }
  // host:port
  const colon: number = rest.lastIndexOf(':');
  let host: string = rest;
  let port: string = '';
  if (colon >= 0 && rest.indexOf(':') === colon) {
    host = rest.substring(0, colon);
    port = rest.substring(colon + 1);
    const portNum: number = parseInt(port, 10);
    if (isNaN(portNum) || portNum < 0 || portNum > 65535) {
      return fail(UrlParseFailureCode.NO_HOST);
    }
  }
  if (host.length === 0) {
    return fail(UrlParseFailureCode.NO_HOST);
  }
  let effectivePort: string = port;
  if (effectivePort.length === 0) {
    if (scheme === 'http') {
      effectivePort = '80';
    } else if (scheme === 'https') {
      effectivePort = '443';
    }
  }
  // query pairs
  const pairs: Array<UrlQueryPair> = [];
  if (query.length > 0) {
    const segs: Array<string> = query.split('&');
    for (let i = 0; i < segs.length; i++) {
      const seg: string = segs[i];
      if (seg.length === 0) {
        continue;
      }
      const eq: number = seg.indexOf('=');
      const rawKey: string = eq < 0 ? seg : seg.substring(0, eq);
      const rawValue: string = eq < 0 ? '' : seg.substring(eq + 1);
      pairs.push(new UrlQueryPair(rawKey, rawValue,
        decodeURIComponentSafe(rawKey.replace(/\+/g, ' ')),
        decodeURIComponentSafe(rawValue.replace(/\+/g, ' '))));
    }
  }
  return new UrlParseResult(true, new UrlParseFailure(UrlParseFailureCode.NONE, []),
    scheme, userinfo, host, port, effectivePort, path, query, fragment, pairs);
}
