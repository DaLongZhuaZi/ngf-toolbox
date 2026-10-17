/**
 * 32 位位运算的纯逻辑实现。
 *
 * ## 为什么不用 >>> 与 <<
 *
 * hypium 对超 31 位值的移位运算符结果不可靠（checksum 第 81 轮实测）。
 * 全部位运算用**数学等价**表达：
 * - 逻辑右移 x >> n（无符号）= Math.floor(x / 2^n)
 * - 左移 x << n = x * 2^n，再归一到 32 位（负则加 2^32）
 * - AND/OR/XOR 结果可能为负（JS 位运算转 32 位有符号）——负则加 2^32
 *
 * ## 位面板
 *
 * 输入归一成 0..2^32-1 的无符号数后，按位拆成 32 个 0/1（bit31 在左），
 * 页面渲染 32 个格子。翻转某位 = 值 XOR 2^bit。
 *
 * @module tools/bit-ops/BitOps
 */

const TWO_POW_32: number = 4294967296;

/** 归一到无符号 32 位（负则加 2^32） */
export function toUnsigned32(value: number): number {
  let v: number = value;
  while (v < 0) {
    v = v + TWO_POW_32;
  }
  while (v >= TWO_POW_32) {
    v = v - TWO_POW_32;
  }
  return v;
}

/** 逻辑右移（无符号）：Math.floor 除法 */
export function shr32(value: number, n: number): number {
  return Math.floor(toUnsigned32(value) / Math.pow(2, n));
}

/** 左移：乘法后归一 */
export function shl32(value: number, n: number): number {
  return toUnsigned32(toUnsigned32(value) * Math.pow(2, n));
}

/** 位操作码 */
export enum BitOp {
  AND = 'and',
  OR = 'or',
  XOR = 'xor',
  NOT = 'not',
  SHL = 'shl',
  SHR = 'shr'
}

/** 失败原因码 */
export enum BitOpsFailureCode {
  NONE = 'none',
  EMPTY_LEFT = 'empty_left',
  /** 右操作数非法（AND/OR/XOR 需要它；NOT 不需要） */
  EMPTY_RIGHT = 'empty_right',
  /** 移位量超出 0-31 */
  SHIFT_OUT_OF_RANGE = 'shift_out_of_range'
}

/** 一次失败的原因与文案参数 */
export class BitOpsFailure {
  readonly code: BitOpsFailureCode;
  readonly args: Array<string>;

  constructor(code: BitOpsFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 结果：值 + 32 位面板 */
export class BitOpsResult {
  readonly ok: boolean;
  readonly failure: BitOpsFailure;
  readonly value: number;
  /** 32 个 0/1，index 0 = bit31（左）到 index 31 = bit0（右） */
  readonly bits: Array<number>;

  constructor(ok: boolean, failure: BitOpsFailure, value: number, bits: Array<number>) {
    this.ok = ok;
    this.failure = failure;
    this.value = value;
    this.bits = bits;
  }
}

/** 把无符号 32 位数拆成位面板（index 0 = bit31） */
export function toBitPanel(value: number): Array<number> {
  const v: number = toUnsigned32(value);
  const bits: Array<number> = [];
  for (let i = 31; i >= 0; i--) {
    bits.push(Math.floor(v / Math.pow(2, i)) % 2);
  }
  return bits;
}

/** 解析输入：十进制或 0x/0X 十六进制 */
export function parseBitInput(input: string): number {
  const text: string = input.trim();
  if (text.length === 0) {
    return -1;
  }
  const lower: string = text.toLowerCase();
  if (lower.indexOf('0x') === 0) {
    const hexPart: string = lower.substring(2);
    if (hexPart.length === 0 || hexPart.length > 8) {
      return -1;
    }
    let value: number = 0;
    for (let i = 0; i < hexPart.length; i++) {
      const ch: string = hexPart.charAt(i);
      let v: number = -1;
      if (ch >= '0' && ch <= '9') {
        v = ch.charCodeAt(0) - 48;
      } else if (ch >= 'a' && ch <= 'f') {
        v = ch.charCodeAt(0) - 87;
      }
      if (v < 0) {
        return -1;
      }
      value = value * 16 + v;
    }
    return toUnsigned32(value);
  }
  if (/^[0-9]+$/.test(text)) {
    return toUnsigned32(parseInt(text, 10));
  }
  return -1;
}

/** XOR（数学归一） */
function xor32(a: number, b: number): number {
  let r: number = a ^ b;
  if (r < 0) {
    r = r + TWO_POW_32;
  }
  return r;
}

function and32(a: number, b: number): number {
  let r: number = a & b;
  if (r < 0) {
    r = r + TWO_POW_32;
  }
  return r;
}

function or32(a: number, b: number): number {
  let r: number = a | b;
  if (r < 0) {
    r = r + TWO_POW_32;
  }
  return r;
}

/** 主入口：执行位操作 */
export function executeBitOp(op: BitOp, leftText: string, rightText: string): BitOpsResult {
  const left: number = parseBitInput(leftText);
  if (left < 0) {
    return new BitOpsResult(false, new BitOpsFailure(BitOpsFailureCode.EMPTY_LEFT, []), 0, []);
  }
  if (op === BitOp.NOT) {
    const v: number = xor32(left, TWO_POW_32 - 1);
    return new BitOpsResult(true, new BitOpsFailure(BitOpsFailureCode.NONE, []), v, toBitPanel(v));
  }
  const right: number = parseBitInput(rightText);
  if (op === BitOp.SHL || op === BitOp.SHR) {
    // 移位量是十进制小整数
    const n: number = parseInt(rightText.trim(), 10);
    if (isNaN(n) || n < 0 || n > 31) {
      return new BitOpsResult(false,
        new BitOpsFailure(BitOpsFailureCode.SHIFT_OUT_OF_RANGE, [rightText]), 0, []);
    }
    const v: number = op === BitOp.SHL ? shl32(left, n) : shr32(left, n);
    return new BitOpsResult(true, new BitOpsFailure(BitOpsFailureCode.NONE, []), v, toBitPanel(v));
  }
  if (right < 0) {
    return new BitOpsResult(false, new BitOpsFailure(BitOpsFailureCode.EMPTY_RIGHT, []), 0, []);
  }
  let v: number = 0;
  if (op === BitOp.AND) {
    v = and32(left, right);
  } else if (op === BitOp.OR) {
    v = or32(left, right);
  } else {
    v = xor32(left, right);
  }
  return new BitOpsResult(true, new BitOpsFailure(BitOpsFailureCode.NONE, []), v, toBitPanel(v));
}

/** 翻转某一位（页面位格子点击） */
export function flipBit(value: number, bitIndex: number): number {
  // bitIndex 0..31，0 = bit0（最低位）
  return xor32(toUnsigned32(value), Math.pow(2, bitIndex));
}
