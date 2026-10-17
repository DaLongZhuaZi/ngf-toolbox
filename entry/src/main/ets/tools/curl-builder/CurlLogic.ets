/**
 * HTTP 命令生成的纯逻辑实现（cURL 与 HTTPie 双输出）。
 *
 * ## 规则
 *
 * 输入 method/URL/请求头（多行 k: v）/请求体。cURL 输出带 -X -H -d；
 * HTTPie 输出带 method URL k:v 与 --data。URL 缺 scheme 补 https://。
 * GET 请求不带 body。值里的单引号按 Shell 规则转义（' -> '\''）。
 *
 * @module tools/curl-builder/CurlLogic
 */

/** 失败原因码 */
export enum CurlFailureCode {
  NONE = 'none',
  EMPTY_URL = 'empty_url',
  BAD_HEADER = 'bad_header'
}

/** 一次失败的原因与文案参数 */
export class CurlFailure {
  readonly code: CurlFailureCode;
  readonly args: Array<string>;

  constructor(code: CurlFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 结果 */
export class CurlResult {
  readonly ok: boolean;
  readonly failure: CurlFailure;
  readonly curl: string;
  readonly httpie: string;

  constructor(ok: boolean, failure: CurlFailure, curl: string, httpie: string) {
    this.ok = ok;
    this.failure = failure;
    this.curl = curl;
    this.httpie = httpie;
  }
}

const SPACE: string = String.fromCharCode(32);
const SQUOTE: string = String.fromCharCode(39);
const NEWLINE: string = String.fromCharCode(10);

/** Shell 单引号转义：' -> '\'' */
function shellEscape(text: string): string {
  return SQUOTE + text.split(SQUOTE).join(SQUOTE + String.fromCharCode(92) + SQUOTE + SQUOTE) + SQUOTE;
}

export function normalizeUrl(raw: string): string {
  const t: string = raw.trim();
  if (t.indexOf('://') < 0) {
    return 'https://' + t;
  }
  return t;
}

/** 请求头解析：每行 k: v；空行跳过；无冒号报错 */
function parseHeaders(multiline: string): Array<string> | null {
  const out: Array<string> = [];
  const rawLines: Array<string> = multiline.split(NEWLINE);
  for (let i = 0; i < rawLines.length; i++) {
    const line: string = rawLines[i].trim();
    if (line.length === 0) {
      continue;
    }
    const colon: number = line.indexOf(':');
    if (colon <= 0) {
      return null;
    }
    const key: string = line.substring(0, colon).trim();
    const value: string = line.substring(colon + 1).trim();
    out.push(key + ': ' + value);
  }
  return out;
}

/** 主入口 */
export function buildHttpCommand(method: string, urlRaw: string,
  headerLines: string, body: string): CurlResult {
  const url: string = normalizeUrl(urlRaw);
  if (urlRaw.trim().length === 0) {
    return new CurlResult(false, new CurlFailure(CurlFailureCode.EMPTY_URL, []), '', '');
  }
  const headers: Array<string> | null = parseHeaders(headerLines);
  if (headers === null) {
    return new CurlResult(false, new CurlFailure(CurlFailureCode.BAD_HEADER, []), '', '');
  }
  const m: string = method.trim().toUpperCase();
  const hasBody: boolean = body.trim().length > 0 && m !== 'GET';
  // cURL
  const curlParts: Array<string> = ['curl', '-X', m, shellEscape(url)];
  for (let i = 0; i < headers.length; i++) {
    curlParts.push('-H');
    curlParts.push(shellEscape(headers[i]));
  }
  if (hasBody) {
    curlParts.push('-d');
    curlParts.push(shellEscape(body.trim()));
  }
  const curl: string = curlParts.join(SPACE);
  // HTTPie
  const httpieParts: Array<string> = ['http', m, url];
  for (let i = 0; i < headers.length; i++) {
    const colon: number = headers[i].indexOf(':');
    httpieParts.push(shellEscape(headers[i].substring(0, colon)) + ':' +
      shellEscape(headers[i].substring(colon + 2)));
  }
  if (hasBody) {
    httpieParts.push('--data=' + shellEscape(body.trim()));
  }
  const httpie: string = httpieParts.join(SPACE);
  return new CurlResult(true, new CurlFailure(CurlFailureCode.NONE, []), curl, httpie);
}