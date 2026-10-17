/**
 * JWT 构建的纯逻辑实现（HS256 本地签名，演示口径）。
 *
 * ## 组装链
 *
 * header 固定 JSON；payload 由调用方给 JSON；各段 utf8 转码 Base64 再转 base64url；
 * 签名用 HMAC-SHA256。复用 codec-suite 的编码与 hmac-calc 的签名——不复制实现。
 * 仅演示：不做密钥强度校验、不加密钥管理。
 *
 * @module tools/jwt-builder/JwtBuilderLogic
 */

import { base64EncodeBytes, utf8BytesOf } from '../codec-suite/CodecLogic';
import { computeHmac, HmacAlgorithm } from '../hmac-calc/HmacCalc';

/** 失败原因码 */
export enum JwtBuildFailureCode {
  NONE = 'none',
  EMPTY_PAYLOAD = 'empty_payload',
  EMPTY_SECRET = 'empty_secret',
  BAD_PAYLOAD_JSON = 'bad_payload_json'
}

/** 一次失败的原因与文案参数 */
export class JwtBuildFailure {
  readonly code: JwtBuildFailureCode;
  readonly args: Array<string>;

  constructor(code: JwtBuildFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 结果 */
export class JwtBuildResult {
  readonly ok: boolean;
  readonly failure: JwtBuildFailure;
  readonly token: string;
  readonly headerB64: string;
  readonly payloadB64: string;
  readonly signatureB64: string;

  constructor(ok: boolean, failure: JwtBuildFailure, token: string,
    headerB64: string, payloadB64: string, signatureB64: string) {
    this.ok = ok;
    this.failure = failure;
    this.token = token;
    this.headerB64 = headerB64;
    this.payloadB64 = payloadB64;
    this.signatureB64 = signatureB64;
  }
}

/** 标准 Base64 转 base64url（加号转横线、斜杠转下划线、去填充） */
export function toBase64Url(b64: string): string {
  let out: string = b64.split('+').join('-');
  out = out.split('/').join('_');
  while (out.charAt(out.length - 1) === '=') {
    out = out.substring(0, out.length - 1);
  }
  return out;
}

/** 十六进制串转字节数组 */
function hexToBytes(hex: string): Array<number> {
  const out: Array<number> = [];
  for (let i = 0; i + 1 < hex.length; i = i + 2) {
    out.push(parseInt(hex.substring(i, i + 2), 16));
  }
  return out;
}

/** JSON 文本转 base64url */
function jsonToB64Url(json: string): string {
  return toBase64Url(base64EncodeBytes(utf8BytesOf(json)));
}

/** 主入口 */
export function buildJwt(payloadJson: string, secret: string): JwtBuildResult {
  if (payloadJson.trim().length === 0) {
    return new JwtBuildResult(false, new JwtBuildFailure(JwtBuildFailureCode.EMPTY_PAYLOAD, []), '', '', '', '');
  }
  if (secret.length === 0) {
    return new JwtBuildResult(false, new JwtBuildFailure(JwtBuildFailureCode.EMPTY_SECRET, []), '', '', '', '');
  }
  try {
    JSON.parse(payloadJson);
  } catch (e) {
    return new JwtBuildResult(false, new JwtBuildFailure(JwtBuildFailureCode.BAD_PAYLOAD_JSON, []), '', '', '', '');
  }
  const headerJson: string = '{"alg":"HS256","typ":"JWT"}';
  const headerB64: string = jsonToB64Url(headerJson);
  const payloadB64: string = jsonToB64Url(payloadJson.trim());
  const signingInput: string = headerB64 + '.' + payloadB64;
  const mac = computeHmac(HmacAlgorithm.SHA256, signingInput, secret);
  if (!mac.ok) {
    return new JwtBuildResult(false, new JwtBuildFailure(JwtBuildFailureCode.EMPTY_SECRET, []), '', '', '', '');
  }
  const signatureB64: string = toBase64Url(base64EncodeBytes(hexToBytes(mac.hex)));
  const token: string = signingInput + '.' + signatureB64;
  return new JwtBuildResult(true, new JwtBuildFailure(JwtBuildFailureCode.NONE, []),
    token, headerB64, payloadB64, signatureB64);
}