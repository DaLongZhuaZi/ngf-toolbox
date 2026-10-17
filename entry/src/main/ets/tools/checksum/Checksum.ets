/**
 * 校验和的纯逻辑实现：CRC-32（IEEE 802.3）与 Adler-32（RFC 1950）。
 *
 * ## 用途边界（limitation 会写明）
 *
 * 两者都是**完整性校验**（检测传输/存储损坏），**不是加密哈希**——
 * 碰撞在恶意场景下可构造。CRC-32 常见于 zip/以太网，Adler-32 常见于 zlib。
 *
 * ## 实现
 *
 * CRC-32 查表法（生成多项式 0xEDB88320， reflected）；
 * Adler-32 按规范分 mod 65521 累加。输入 UTF-8 编码后按字节算（复用 HashCore）。
 *
 * @module tools/checksum/Checksum
 */

import { utf8Encode } from '../digest/HashCore';

/** 校验和算法 */
export enum ChecksumAlgorithm {
  CRC32 = 'crc32',
  ADLER32 = 'adler32'
}

/** 失败原因码 */
export enum ChecksumFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input'
}

/** 一次失败的原因与文案参数 */
export class ChecksumFailure {
  readonly code: ChecksumFailureCode;
  readonly args: Array<string>;

  constructor(code: ChecksumFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 结果：十进制与十六进制两种展示 */
export class ChecksumResult {
  readonly ok: boolean;
  readonly failure: ChecksumFailure;
  readonly decimal: string;
  readonly hex: string;

  constructor(ok: boolean, failure: ChecksumFailure, decimal: string, hex: string) {
    this.ok = ok;
    this.failure = failure;
    this.decimal = decimal;
    this.hex = hex;
  }
}

/** CRC-32 查表（模块级一次构建；39 项命名实体同款——避免 Map+IIFE 的运行时差异） */
const CRC_TABLE: Array<number> = ((): Array<number> => {
  const table: Array<number> = [];
  for (let n = 0; n < 256; n++) {
    let c: number = n;
    for (let k = 0; k < 8; k++) {
      const half: number = Math.floor(c / 2);
      if (c % 2 === 1) {
        // JS 的 ^ 把操作数转 32 位有符号：0xEDB88320 参与后结果可能为负，
        // 必须用「负则加 2^32」归一无符号（>>> 0 在 hypium 对超 31 位值不可靠）。
        let x: number = 0xEDB88320 ^ half;
        if (x < 0) {
          x = x + 4294967296;
        }
        c = x;
      } else {
        c = half;
      }
    }
    table[n] = c;
  }
  return table;
})();

/** CRC-32（IEEE，reflected） */
export function crc32OfBytes(bytes: Uint8Array): number {
  let crc: number = 4294967295;
  for (let i = 0; i < bytes.length; i++) {
    let x2: number = crc ^ bytes[i];
    if (x2 < 0) {
      x2 = x2 + 4294967296;
    }
    crc = (CRC_TABLE[x2 & 0xFF] ^ Math.floor(x2 / 256)) % 4294967296;
  }
  let fin: number = crc ^ 4294967295;
  if (fin < 0) {
    fin = fin + 4294967296;
  }
  return fin;
}

/** Adler-32（RFC 1950） */
export function adler32OfBytes(bytes: Uint8Array): number {
  let a: number = 1;
  let b: number = 0;
  for (let i = 0; i < bytes.length; i++) {
    a = (a + bytes[i]) % 65521;
    b = (b + a) % 65521;
  }
  return (b * 65536 + a) >>> 0;
}

/** 主入口 */
export function computeChecksum(algorithm: ChecksumAlgorithm, input: string): ChecksumResult {
  if (input.length === 0) {
    return new ChecksumResult(false,
      new ChecksumFailure(ChecksumFailureCode.EMPTY_INPUT, []), '', '');
  }
  const bytes: Uint8Array = utf8Encode(input);
  const value: number = algorithm === ChecksumAlgorithm.CRC32
    ? crc32OfBytes(bytes)
    : adler32OfBytes(bytes);
  const digits: string = String.fromCharCode(48, 49, 50, 51, 52, 53, 54, 55, 56, 57,
    65, 66, 67, 68, 69, 70);
  let hex: string = '';
  for (let shift = 28; shift >= 0; shift = shift - 4) {
    hex = hex + digits.charAt((value >>> shift) & 0xF);
  }
  return new ChecksumResult(true,
    new ChecksumFailure(ChecksumFailureCode.NONE, []), String(value >>> 0), hex);
}
