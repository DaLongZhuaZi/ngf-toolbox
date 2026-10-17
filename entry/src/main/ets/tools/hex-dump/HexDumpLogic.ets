/**
 * 十六进制转储的纯逻辑实现。
 *
 * ## 输出形态
 *
 * 经典三列：偏移量（4 位 hex）、十六进制字节（每行 16 个）、ASCII 预览
 * （不可打印字符显示点）。
 *
 * @module tools/hex-dump/HexDumpLogic
 */

import { utf8Encode } from '../digest/HashCore';

/** 失败原因码 */
export enum HexDumpFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input'
}

/** 一次失败的原因与文案参数 */
export class HexDumpFailure {
  readonly code: HexDumpFailureCode;
  readonly args: Array<string>;

  constructor(code: HexDumpFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}
/** 结果 */
export class HexDumpResult {
  readonly ok: boolean;
  readonly failure: HexDumpFailure;
  readonly dump: string;
  readonly byteCount: number;

  constructor(ok: boolean, failure: HexDumpFailure, dump: string, byteCount: number) {
    this.ok = ok;
    this.failure = failure;
    this.dump = dump;
    this.byteCount = byteCount;
  }
}

const NEWLINE: string = String.fromCharCode(10);
const SPACE: string = String.fromCharCode(32);
const DOT: string = String.fromCharCode(46);

function toHex2(v: number): string {
  const h: string = v.toString(16).toUpperCase();
  if (h.length === 1) {
    return '0' + h;
  }
  return h;
}

/** ASCII 预览：可打印保留，否则点 */
function asciiPreview(b: number): string {
  if (b >= 32 && b < 127) {
    return String.fromCharCode(b);
  }
  return DOT;
}
/** 主入口 */
export function hexDump(input: string): HexDumpResult {
  if (input.length === 0) {
    return new HexDumpResult(false, new HexDumpFailure(HexDumpFailureCode.EMPTY_INPUT, []), '', 0);
  }
  const bytes: Uint8Array = utf8Encode(input);
  const out: Array<string> = [];
  for (let offset = 0; offset < bytes.length; offset = offset + 16) {
    const hexPart: Array<string> = [];
    const asciiPart: Array<string> = [];
    for (let j = 0; j < 16; j++) {
      const idx: number = offset + j;
      if (idx < bytes.length) {
        hexPart.push(toHex2(bytes[idx]));
        asciiPart.push(asciiPreview(bytes[idx]));
      } else {
        hexPart.push('  ');
        asciiPart.push(SPACE);
      }
    }
    const offsetStr: string = toHex2(Math.floor(offset / 256)) + toHex2(offset % 256);
    const hexLine: string = hexPart.join(SPACE);
    out.push(offsetStr + '  ' + hexLine + '  ' + asciiPart.join(''));
  }
  return new HexDumpResult(true, new HexDumpFailure(HexDumpFailureCode.NONE, []),
    out.join(NEWLINE), bytes.length);
}