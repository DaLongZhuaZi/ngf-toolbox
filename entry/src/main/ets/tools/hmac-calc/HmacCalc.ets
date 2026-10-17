/**
 * HMAC 计算的纯逻辑实现（复用 digest 工具的 HashCore）。
 *
 * ## 公式（RFC 2104）
 *
 * HMAC(K, M) = H((K ⊕ opad) || H((K ⊕ ipad) || M))
 * 其中 ipad = 0x36 重复、opad = 0x5c 重复，块大小 64 字节（MD5/SHA-1/SHA-256 同）。
 * 密钥长于块大小时先 H(K) 再补零；短于块长补零到块长。
 *
 * ## 复用边界
 *
 * utf8Encode 与三个 hash 函数直接 import 自 digest/HashCore——**不复制一份**，
 * 两处漂移是迟早的事（跨工具复用的意义就在这里）。
 *
 * @module tools/hmac-calc/HmacCalc
 */

import { md5HexOfBytes, sha1HexOfBytes, sha256HexOfBytes, utf8Encode } from '../digest/HashCore';

/** 支持的哈希算法 */
export enum HmacAlgorithm {
  MD5 = 'md5',
  SHA1 = 'sha1',
  SHA256 = 'sha256'
}

const BLOCK_SIZE: number = 64;
const IPAD: number = 0x36;
const OPAD: number = 0x5c;

/** 失败原因码 */
export enum HmacFailureCode {
  NONE = 'none',
  EMPTY_MESSAGE = 'empty_message',
  EMPTY_KEY = 'empty_key'
}

/** 一次失败的原因与文案参数 */
export class HmacFailure {
  readonly code: HmacFailureCode;
  readonly args: Array<string>;

  constructor(code: HmacFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 计算结果 */
export class HmacResult {
  readonly ok: boolean;
  readonly failure: HmacFailure;
  /** 十六进制大写（与 digest 工具的展示口径一致） */
  readonly hex: string;

  constructor(ok: boolean, failure: HmacFailure, hex: string) {
    this.ok = ok;
    this.failure = failure;
    this.hex = hex;
  }
}

function xorPad(key: Uint8Array, pad: number): Uint8Array {
  const out: Uint8Array = new Uint8Array(BLOCK_SIZE);
  for (let i = 0; i < BLOCK_SIZE; i++) {
    const k: number = i < key.length ? key[i] : 0;
    out[i] = k ^ pad;
  }
  return out;
}

function concat(a: Uint8Array, b: Uint8Array): Uint8Array {
  const out: Uint8Array = new Uint8Array(a.length + b.length);
  for (let i = 0; i < a.length; i++) {
    out[i] = a[i];
  }
  for (let i = 0; i < b.length; i++) {
    out[a.length + i] = b[i];
  }
  return out;
}

function hashBytes(algorithm: HmacAlgorithm, bytes: Uint8Array): Uint8Array {
  const hex: string = algorithm === HmacAlgorithm.MD5 ? md5HexOfBytes(bytes)
    : algorithm === HmacAlgorithm.SHA1 ? sha1HexOfBytes(bytes)
      : sha256HexOfBytes(bytes);
  // 十六进制转字节
  const out: Uint8Array = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) {
    const hi: number = parseInt(hex.charAt(i * 2), 16);
    const lo: number = parseInt(hex.charAt(i * 2 + 1), 16);
    out[i] = hi * 16 + lo;
  }
  return out;
}

/** HMAC 主入口 */
export function computeHmac(algorithm: HmacAlgorithm, message: string, key: string): HmacResult {
  if (message.length === 0) {
    return new HmacResult(false, new HmacFailure(HmacFailureCode.EMPTY_MESSAGE, []), '');
  }
  if (key.length === 0) {
    return new HmacResult(false, new HmacFailure(HmacFailureCode.EMPTY_KEY, []), '');
  }
  let keyBytes: Uint8Array = utf8Encode(key);
  if (keyBytes.length > BLOCK_SIZE) {
    keyBytes = hashBytes(algorithm, keyBytes);
  }
  const inner: Uint8Array = hashBytes(algorithm, concat(xorPad(keyBytes, IPAD), utf8Encode(message)));
  const outer: Uint8Array = hashBytes(algorithm, concat(xorPad(keyBytes, OPAD), inner));
  // 转十六进制大写
  let hex: string = '';
  for (let i = 0; i < outer.length; i++) {
    const hi: number = Math.floor(outer[i] / 16);
    const lo: number = outer[i] % 16;
    hex = hex + (hi < 10 ? String.fromCharCode(48 + hi) : String.fromCharCode(55 + hi));
    hex = hex + (lo < 10 ? String.fromCharCode(48 + lo) : String.fromCharCode(55 + lo));
  }
  return new HmacResult(true, new HmacFailure(HmacFailureCode.NONE, []), hex);
}
