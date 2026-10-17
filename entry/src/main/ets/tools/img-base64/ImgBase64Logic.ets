/**
 * Base64 图片预览的纯逻辑实现。
 *
 * ## 功能
 *
 * 输入 data URI 或裸 Base64，校验格式、解析 MIME（data URI 头或魔数猜测）、
 * 估算原始体积（Base64 4 字符 = 3 字节）。输出可直接给 Image 组件的 data URI。
 *
 * @module tools/img-base64/ImgBase64Logic
 */

/** 失败原因码 */
export enum ImgB64FailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  BAD_BASE64 = 'bad_base64'
}

/** 一次失败的原因与文案参数 */
export class ImgB64Failure {
  readonly code: ImgB64FailureCode;
  readonly args: Array<string>;

  constructor(code: ImgB64FailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 结果 */
export class ImgB64Result {
  readonly ok: boolean;
  readonly failure: ImgB64Failure;
  /** 规范化的 data URI（可直接给 Image） */
  readonly dataUri: string;
  readonly mime: string;
  /** 原始二进制字节数（估算） */
  readonly originalBytes: number;
  /** Base64 文本长度 */
  readonly base64Length: number;

  constructor(ok: boolean, failure: ImgB64Failure, dataUri: string, mime: string,
    originalBytes: number, base64Length: number) {
    this.ok = ok;
    this.failure = failure;
    this.dataUri = dataUri;
    this.mime = mime;
    this.originalBytes = originalBytes;
    this.base64Length = base64Length;
  }
}

const B64_CHARS: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';

/** 主入口 */
export function analyzeBase64Image(input: string): ImgB64Result {
  if (input.trim().length === 0) {
    return new ImgB64Result(false, new ImgB64Failure(ImgB64FailureCode.EMPTY_INPUT, []), '', '', 0, 0);
  }
  const text: string = input.trim();
  let mime: string = 'image/png';
  let b64: string = text;
  if (text.indexOf('data:') === 0) {
    const comma: number = text.indexOf(',');
    if (comma < 0) {
      return new ImgB64Result(false, new ImgB64Failure(ImgB64FailureCode.BAD_BASE64, []), '', '', 0, 0);
    }
    const header: string = text.substring(5, comma);
    const semi: number = header.indexOf(';');
    mime = semi > 0 ? header.substring(0, semi) : header;
    b64 = text.substring(comma + 1);
  } else {
    if (text.indexOf('iVBOR') === 0) {
      mime = 'image/png';
    } else if (text.indexOf('/9j/') === 0) {
      mime = 'image/jpeg';
    } else if (text.indexOf('R0lGOD') === 0) {
      mime = 'image/gif';
    } else if (text.indexOf('UklGR') === 0) {
      mime = 'image/webp';
    }
  }
  for (let i = 0; i < b64.length; i++) {
    const ch: string = b64.charAt(i);
    const isB64: boolean = B64_CHARS.indexOf(ch) >= 0;
    const isNewline: boolean = ch === String.fromCharCode(10) || ch === String.fromCharCode(13);
    if (!isB64 && !isNewline) {
      return new ImgB64Result(false, new ImgB64Failure(ImgB64FailureCode.BAD_BASE64, []), '', '', 0, 0);
    }
  }
  let cleaned: string = '';
  for (let i = 0; i < b64.length; i++) {
    const chC: string = b64.charAt(i);
    if (chC !== String.fromCharCode(10) && chC !== String.fromCharCode(13)) {
      cleaned = cleaned + chC;
    }
  }
  if (cleaned.length === 0) {
    return new ImgB64Result(false, new ImgB64Failure(ImgB64FailureCode.BAD_BASE64, []), '', '', 0, 0);
  }
  let contentLen: number = b64.length;
  if (b64.indexOf('==') >= 0) {
    contentLen = contentLen - 2;
  } else if (b64.charAt(b64.length - 1) === '=') {
    contentLen = contentLen - 1;
  }
  const originalBytes: number = Math.floor(contentLen * 3 / 4);
  let clean: string = '';
  for (let i = 0; i < b64.length; i++) {
    const ch2: string = b64.charAt(i);
    if (ch2 !== String.fromCharCode(10) && ch2 !== String.fromCharCode(13)) {
      clean = clean + ch2;
    }
  }
  const dataUri: string = 'data:' + mime + ';base64,' + clean;
  return new ImgB64Result(true, new ImgB64Failure(ImgB64FailureCode.NONE, []),
    dataUri, mime, originalBytes, b64.length);
}