/**
 * 字节序演示的纯逻辑实现（Endianness）。
 *
 * ## 功能
 *
 * 输入 32 位无符号整数，输出大端（Big-Endian）与小端（Little-Endian）的
 * 字节排列对照与十六进制展示。网络字节序是大端，x86 内存是小端。
 *
 * @module tools/byte-split/ByteSplitLogic
 */

/** 失败原因码 */
export enum ByteSplitFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  OUT_OF_RANGE = 'out_of_range'
}

/** 一次失败的原因与文案参数 */
export class ByteSplitFailure {
  readonly code: ByteSplitFailureCode;
  readonly args: Array<string>;

  constructor(code: ByteSplitFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 结果 */
export class ByteSplitResult {
  readonly ok: boolean;
  readonly failure: ByteSplitFailure;
  readonly hexBigEndian: string;
  readonly hexLittleEndian: string;
  /** 大端字节序（网络序） */
  readonly bytesBig: Array<number>;
  /** 小端字节序（x86 内存序） */
  readonly bytesLittle: Array<number>;

  constructor(ok: boolean, failure: ByteSplitFailure, hexBigEndian: string,
    hexLittleEndian: string, bytesBig: Array<number>, bytesLittle: Array<number>) {
    this.ok = ok;
    this.failure = failure;
    this.hexBigEndian = hexBigEndian;
    this.hexLittleEndian = hexLittleEndian;
    this.bytesBig = bytesBig;
    this.bytesLittle = bytesLittle;
  }
}

function toHex2(v: number): string {
  const h: string = v.toString(16).toUpperCase();
  if (h.length === 1) {
    return '0' + h;
  }
  return h;
}

/** 主入口 */
export function splitBytes(input: string): ByteSplitResult {
  if (input.trim().length === 0) {
    return new ByteSplitResult(false, new ByteSplitFailure(ByteSplitFailureCode.EMPTY_INPUT, []), '', '', [], []);
  }
  const value: number = parseInt(input.trim(), 10);
  if (isNaN(value) || value < 0 || value > 4294967295) {
    return new ByteSplitResult(false, new ByteSplitFailure(ByteSplitFailureCode.OUT_OF_RANGE, []), '', '', [], []);
  }
  const b3: number = Math.floor(value / 16777216) % 256;
  const b2: number = Math.floor(value / 65536) % 256;
  const b1: number = Math.floor(value / 256) % 256;
  const b0: number = value % 256;
  const big: Array<number> = [b3, b2, b1, b0];
  const little: Array<number> = [b0, b1, b2, b3];
  const hexBig: string = toHex2(b3) + ' ' + toHex2(b2) + ' ' + toHex2(b1) + ' ' + toHex2(b0);
  const hexLittle: string = toHex2(b0) + ' ' + toHex2(b1) + ' ' + toHex2(b2) + ' ' + toHex2(b3);
  return new ByteSplitResult(true, new ByteSplitFailure(ByteSplitFailureCode.NONE, []),
    hexBig, hexLittle, big, little);
}
