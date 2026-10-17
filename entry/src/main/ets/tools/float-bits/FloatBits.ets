/**
 * IEEE-754 位分解的纯逻辑实现（单精度 32 位 / 双精度 64 位）。
 *
 * ## 方法
 *
 * 用 ArrayBuffer + Float32Array/Float64Array 写入、Uint32Array 读出——
 * 这是标准类型化数组用法（digest 的 HashCore 已验证 Uint8Array 在两个运行器一致）。
 * 不手写舍入/规范化算法——那是浮点标准的复制，错了更难发现。
 *
 * ## 输出
 *
 * sign（1 位）/ exponent（8 或 11 位）/ mantissa（23 或 52 位），
 * 外加「规格化数/非规格化数/零/无穷/NaN」分类——**五个分类的判定**
 * 用指数与尾数的位模式判断（全 0 指数 = 非规格化或零；全 1 = 无穷或 NaN）。
 *
 * @module tools/float-bits/FloatBits
 */

/** 精度 */
export enum FloatPrecision {
  SINGLE = 'single',
  DOUBLE = 'double'
}

/** 值分类 */
export enum FloatValueClass {
  NORMAL = 'normal',
  SUBNORMAL = 'subnormal',
  ZERO = 'zero',
  INFINITY = 'infinity',
  NAN = 'nan'
}

/** 失败原因码 */
export enum FloatBitsFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  NOT_A_NUMBER = 'not_a_number'
}

/** 一次失败的原因与文案参数 */
export class FloatBitsFailure {
  readonly code: FloatBitsFailureCode;
  readonly args: Array<string>;

  constructor(code: FloatBitsFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 分解结果 */
export class FloatBitsResult {
  readonly ok: boolean;
  readonly failure: FloatBitsFailure;
  readonly precision: FloatPrecision;
  /** 符号位 0/1 */
  readonly sign: number;
  /** 指数位（8 或 11 个 0/1，高位在前） */
  readonly exponentBits: Array<number>;
  /** 尾数位（23 或 52 个 0/1） */
  readonly mantissaBits: Array<number>;
  /** 原始十六进制（32 位 = 8 字符，64 位 = 16 字符） */
  readonly hex: string;
  readonly valueClass: FloatValueClass;

  constructor(ok: boolean, failure: FloatBitsFailure, precision: FloatPrecision,
    sign: number, exponentBits: Array<number>, mantissaBits: Array<number>,
    hex: string, valueClass: FloatValueClass) {
    this.ok = ok;
    this.failure = failure;
    this.precision = precision;
    this.sign = sign;
    this.exponentBits = exponentBits;
    this.mantissaBits = mantissaBits;
    this.hex = hex;
    this.valueClass = valueClass;
  }
}

/** 数字分类判定（按位模式） */
function classify(expAllOnes: boolean, expAllZeros: boolean, mantissaNonZero: boolean): FloatValueClass {
  if (expAllOnes) {
    return mantissaNonZero ? FloatValueClass.NAN : FloatValueClass.INFINITY;
  }
  if (expAllZeros) {
    return mantissaNonZero ? FloatValueClass.SUBNORMAL : FloatValueClass.ZERO;
  }
  return FloatValueClass.NORMAL;
}

function bitsToHexUpper(bits: Array<number>): string {
  // 位列表高位在前，每 4 位一个十六进制字符
  const digits: string = String.fromCharCode(48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 65, 66, 67, 68, 69, 70);
  let hex: string = '';
  for (let i = 0; i < bits.length; i = i + 4) {
    let v: number = 0;
    for (let b = 0; b < 4; b++) {
      v = v * 2 + bits[i + b];
    }
    hex = hex + digits.charAt(v);
  }
  return hex;
}

function toBits(value: number, width: number): Array<number> {
  const bits: Array<number> = [];
  for (let i = width - 1; i >= 0; i--) {
    bits.push(Math.floor(value / Math.pow(2, i)) % 2);
  }
  return bits;
}

/** 主入口 */
export function decomposeFloat(input: string, precision: FloatPrecision): FloatBitsResult {
  const text: string = input.trim();
  if (text.length === 0) {
    return new FloatBitsResult(false,
      new FloatBitsFailure(FloatBitsFailureCode.EMPTY_INPUT, []), FloatPrecision.SINGLE,
      0, [], [], '', FloatValueClass.ZERO);
  }
  const value: number = parseFloat(text);
  // NaN/Infinity 是用户显式想看位型的特殊值，放行到分支内构造；
  // 其它解析不出的输入（如 abc）仍报错——不把拼写错误静默变成 NaN 位型。
  const upper: string = text.toUpperCase();
  const isSpecial: boolean = upper === 'NAN' || upper === 'INFINITY' || upper === '-INFINITY';
  if (isNaN(value) && !isSpecial) {
    return new FloatBitsResult(false,
      new FloatBitsFailure(FloatBitsFailureCode.NOT_A_NUMBER, [text]), FloatPrecision.SINGLE,
      0, [], [], '', FloatValueClass.ZERO);
  }
  if (precision === FloatPrecision.SINGLE) {
    // 特殊值短路：NaN 与 Infinity 的位型是标准固定的。f32 写 NaN 再读 u32
    // 在部分运行器里返回 0（第 85 轮实测），显式构造位型更稳。
    if (value === Infinity || value === -Infinity) {
      const sgn: number = value === -Infinity ? 1 : 0;
      const e2: Array<number> = toBits(255, 8);
      const m2: Array<number> = toBits(0, 23);
      return new FloatBitsResult(true,
        new FloatBitsFailure(FloatBitsFailureCode.NONE, []), FloatPrecision.SINGLE,
        sgn, e2, m2, sgn === 1 ? 'FF800000' : '7F800000', FloatValueClass.INFINITY);
    }
    if (isNaN(value)) {
      const e3: Array<number> = toBits(255, 8);
      const m3: Array<number> = toBits(4194304, 23);
      return new FloatBitsResult(true,
        new FloatBitsFailure(FloatBitsFailureCode.NONE, []), FloatPrecision.SINGLE,
        0, e3, m3, '7FC00000', FloatValueClass.NAN);
    }
    const buffer: ArrayBuffer = new ArrayBuffer(4);
    const f32: Float32Array = new Float32Array(buffer);
    const u32: Uint32Array = new Uint32Array(buffer);
    f32[0] = value;
    const bits: number = u32[0];
    const sign: number = bits >>> 31;
    const exp: number = (bits >>> 23) & 0xFF;
    const man: number = bits & 0x7FFFFF;
    const expBits: Array<number> = toBits(exp, 8);
    const manBits: Array<number> = toBits(man, 23);
    const digits: string = String.fromCharCode(48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 65, 66, 67, 68, 69, 70);
    let hex: string = '';
    for (let shift = 28; shift >= 0; shift = shift - 4) {
      hex = hex + digits.charAt((bits >>> shift) & 0xF);
    }
    const cls: FloatValueClass = classify(exp === 0xFF, exp === 0, man !== 0);
    return new FloatBitsResult(true,
      new FloatBitsFailure(FloatBitsFailureCode.NONE, []), FloatPrecision.SINGLE,
      sign, expBits, manBits, hex, cls);
  }
  // 双精度：64 位拆两个 32 位字
  const buffer: ArrayBuffer = new ArrayBuffer(8);
  const f64: Float64Array = new Float64Array(buffer);
  const u32: Uint32Array = new Uint32Array(buffer);
  f64[0] = value;
  // 字节序：Float64Array/Uint32Array 同端序，u32[0] 是低 32 位、u32[1] 是高 32 位
  const lo: number = u32[0];
  const hi: number = u32[1];
  const sign: number = hi >>> 31;
  const exp: number = (hi >>> 20) & 0x7FF;
  const manHi: number = hi & 0xFFFFF;
  const expBits: Array<number> = toBits(exp, 11);
  const manBits: Array<number> = toBits(manHi, 20).concat(toBits(lo, 32));
  const digits: string = String.fromCharCode(48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 65, 66, 67, 68, 69, 70);
  let hex: string = '';
  for (let shift = 28; shift >= 0; shift = shift - 4) {
    hex = hex + digits.charAt((hi >>> shift) & 0xF);
  }
  for (let shift = 28; shift >= 0; shift = shift - 4) {
    hex = hex + digits.charAt((lo >>> shift) & 0xF);
  }
  const cls: FloatValueClass = classify(exp === 0x7FF, exp === 0, (manHi !== 0 || lo !== 0));
  return new FloatBitsResult(true,
    new FloatBitsFailure(FloatBitsFailureCode.NONE, []), FloatPrecision.DOUBLE,
    sign, expBits, manBits, hex, cls);
}
