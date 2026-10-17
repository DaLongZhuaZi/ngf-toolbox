/**
 * 进制转换与位运算的纯逻辑实现（2-36 进制，任意精度）。
 *
 * ## 为什么全程用字符串算，而不是 Number
 *
 * `Number` 只有 53 位精确整数：`0xFFFFFFFFFFFFFFFFFF` 这种开发者在调试时随手会看的值
 * 一旦走 Number 就会被悄悄改写（末位变成 0）。进制转换工具的**唯一价值**就是「原样搬运」，
 * 所以这里用「数字数组 + 长除法」实现任意精度：输入多长都能算准，只受输入长度限制。
 *
 * ## 位运算为什么是 64 位有符号
 *
 * 位运算没有"任意精度"的自然语义：`~` 的结果取决于字宽。这里统一按 **64 位有符号**处理
 * （与 C/Java 的 long、Java 的 long 一致，也是开发者最常拿来做掩码的宽度）：
 * - 超过 64 位的输入会被**截断到低 64 位**，并在结果里标记 `truncated=true`，
 *   页面必须把这个标记显示出来，而不是假装算对了；
 * - `>>` 是算术右移（保留符号位），`<<` 溢出 64 位的部分被丢弃。
 *
 * @module tools/radix-convert/RadixConvert
 */

/** 支持的进制下限（2 进制） */
export const RADIX_MIN: number = 2;

/** 支持的进制上限（36 进制：0-9 + a-z） */
export const RADIX_MAX: number = 36;

/** 位运算的字宽（位） */
export const BITWISE_WIDTH: number = 64;

/** 支持的位运算 */
export enum NGFBitwiseOperation {
  AND = 'AND',
  OR = 'OR',
  XOR = 'XOR',
  NOT = 'NOT',
  SHIFT_LEFT = '<<',
  SHIFT_RIGHT = '>>'
}

/**
 * 失败原因码。
 *
 * ## 为什么纯逻辑不产出面向用户的句子
 *
 * 这里原先直接返回中文文案（「进制必须是 2-36 之间的整数」）。做双语时发现那样行不通：
 * 本模块是**纯逻辑**，不能 import ArkUI 的 \`$r()\`（一旦 import 就没法在本机跑单测了），
 * 所以它根本没有能力按设备语言选文案。
 *
 * 于是改成：纯逻辑只回答**「因为什么失败」+「文案需要哪些参数」**，
 * 由 UI 层把码翻译成资源键。这样切分还带来两个好处：
 * - 单测断言**错误码**而不是文案。断言文案是脆的——改一个措辞就要改一堆测试，
 *   而码是稳定契约；
 * - 同一个原因在不同工具里的措辞可以统一（以前 16 件工具各写各的，风格并不一致）。
 */
export enum RadixFailureCode {
  /** 没有失败（成功结果的占位，避免到处判空） */
  NONE = 'none',
  RADIX_OUT_OF_RANGE = 'radix_out_of_range',
  EMPTY_INPUT = 'empty_input',
  INVALID_DIGIT = 'invalid_digit',
  UNSUPPORTED_OPERATION = 'unsupported_operation',
  SHIFT_OUT_OF_RANGE = 'shift_out_of_range'
}

/**
 * 一次失败：原因码 + 资源文案的占位符参数。
 *
 * 参数顺序必须与资源文案里 \`%s\` 的出现顺序一致——这条约束由 UI 层的翻译函数
 * 和资源表共同承担，改文案时要一起看。
 */
export class RadixFailure {
  readonly code: RadixFailureCode;
  readonly args: Array<string>;

  constructor(code: RadixFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }

  /** 成功结果的占位失败值：让 \`failure\` 字段总是非空，省掉调用方的判空分支 */
  static none(): RadixFailure {
    return new RadixFailure(RadixFailureCode.NONE, []);
  }
}

/** 单个数（无进制上下文）的解析结果 */
export class RadixValue {
  readonly ok: boolean;
  /** 失败原因；成功时为 {@link RadixFailure.none}（**永不为 null**） */
  readonly failure: RadixFailure;
  /** true 表示负数 */
  readonly negative: boolean;
  /** 解析时使用的进制 */
  readonly radix: number;
  /** 去掉符号/前缀/前导零后的数字串（统一小写；0 就是 '0'） */
  readonly digits: string;

  constructor(ok: boolean, failure: RadixFailure, negative: boolean, radix: number, digits: string) {
    this.ok = ok;
    this.failure = failure;
    this.negative = negative;
    this.radix = radix;
    this.digits = digits;
  }

  static failure(code: RadixFailureCode, args: Array<string>, radix: number): RadixValue {
    return new RadixValue(false, new RadixFailure(code, args), false, radix, '');
  }

  static success(negative: boolean, radix: number, digits: string): RadixValue {
    return new RadixValue(true, RadixFailure.none(), negative, radix, digits);
  }
}

/** 转换/位运算的通用结果 */
export class RadixConvertResult {
  readonly ok: boolean;
  /** 失败原因；成功时为 {@link RadixFailure.none}（**永不为 null**） */
  readonly failure: RadixFailure;
  readonly negative: boolean;
  /** 目标进制的数字串（无符号、无前缀、小写） */
  readonly digits: string;
  /** 带符号与前缀的完整写法，例如 `-0x1f` */
  readonly prefixed: string;
  /** 是否因超出 64 位被截断（只有位运算会置位） */
  readonly truncated: boolean;

  constructor(ok: boolean, failure: RadixFailure, negative: boolean, digits: string, prefixed: string,
    truncated: boolean) {
    this.ok = ok;
    this.failure = failure;
    this.negative = negative;
    this.digits = digits;
    this.prefixed = prefixed;
    this.truncated = truncated;
  }

  static failure(code: RadixFailureCode, args: Array<string>): RadixConvertResult {
    return new RadixConvertResult(false, new RadixFailure(code, args), false, '', '', false);
  }

  /** 把上游（解析阶段）的失败原样传下去，不重新造一个码 */
  static failureOf(failure: RadixFailure): RadixConvertResult {
    return new RadixConvertResult(false, failure, false, '', '', false);
  }

  static success(negative: boolean, digits: string, prefixed: string,
    truncated: boolean): RadixConvertResult {
    return new RadixConvertResult(true, RadixFailure.none(), negative, digits, prefixed, truncated);
  }
}

/** 进制是否合法（区间内且必须是整数——2.5 进制这种东西不该被静默接受） */
export function isValidRadix(radix: number): boolean {
  if (isNaN(radix) || Math.floor(radix) !== radix) {
    return false;
  }
  return radix >= RADIX_MIN && radix <= RADIX_MAX;
}

/** 进制对应的常用前缀（页面展示用；10 进制没有前缀） */
export function radixPrefix(radix: number): string {
  if (radix === 16) {
    return '0x';
  }
  if (radix === 2) {
    return '0b';
  }
  if (radix === 8) {
    return '0o';
  }
  return '';
}

/** 单个字符的数值；非法字符返回 -1 */
function digitValueOf(ch: string): number {
  const code: number = ch.charCodeAt(0);
  if (code >= 48 && code <= 57) {
    return code - 48;
  }
  if (code >= 97 && code <= 122) {
    return code - 97 + 10;
  }
  if (code >= 65 && code <= 90) {
    return code - 65 + 10;
  }
  return -1;
}

/** 数值对应的字符（0-35 → 0-9a-z） */
function digitCharOf(value: number): string {
  if (value < 10) {
    return String.fromCharCode(48 + value);
  }
  return String.fromCharCode(87 + value);
}

/**
 * 解析一个指定进制的整数文本。
 *
 * 容错范围刻意收窄：允许首尾空白、前导 `+`/`-`、与进制匹配的前缀（0x/0b/0o）、
 * 以及数字之间的下划线与空格（`1_000`、`1111 0000` 这种粘贴习惯）。
 * 其余一律报错并指出**是哪个字符**——进制转换最常见的输入错误就是粘了带说明文字的内容。
 */
export function parseRadixValue(input: string, radix: number): RadixValue {
  if (!isValidRadix(radix)) {
    return RadixValue.failure(RadixFailureCode.RADIX_OUT_OF_RANGE,
      [String(RADIX_MIN), String(RADIX_MAX)], radix);
  }
  let text: string = input.trim();
  if (text.length === 0) {
    return RadixValue.failure(RadixFailureCode.EMPTY_INPUT, [], radix);
  }
  let negative: boolean = false;
  if (text.charAt(0) === '+' || text.charAt(0) === '-') {
    negative = text.charAt(0) === '-';
    text = text.substring(1);
  }
  const lower: string = text.toLowerCase();
  if (radix === 16 && lower.length > 2 && lower.substring(0, 2) === '0x') {
    text = text.substring(2);
  } else if (radix === 2 && lower.length > 2 && lower.substring(0, 2) === '0b') {
    text = text.substring(2);
  } else if (radix === 8 && lower.length > 2 && lower.substring(0, 2) === '0o') {
    text = text.substring(2);
  }
  let digits: string = '';
  for (let i: number = 0; i < text.length; i++) {
    const ch: string = text.charAt(i);
    if (ch === '_' || ch === ' ') {
      continue;
    }
    const value: number = digitValueOf(ch);
    if (value < 0 || value >= radix) {
      return RadixValue.failure(RadixFailureCode.INVALID_DIGIT, [ch, String(radix)], radix);
    }
    digits += ch.toLowerCase();
  }
  if (digits.length === 0) {
    return RadixValue.failure(RadixFailureCode.EMPTY_INPUT, [], radix);
  }
  while (digits.length > 1 && digits.charAt(0) === '0') {
    digits = digits.substring(1);
  }
  if (digits === '0') {
    negative = false;
  }
  return RadixValue.success(negative, radix, digits);
}

/** 把数字串（按 radix）转成数值数组，最低位在前 */
function toDigitArray(digits: string, radix: number): number[] {
  const reversed: number[] = [];
  for (let i: number = digits.length - 1; i >= 0; i--) {
    reversed.push(digitValueOf(digits.charAt(i)));
  }
  return reversed;
}

/** 把数值数组（最低位在前）转成数字串；空数组表示 0 */
function fromDigitArray(values: number[]): string {
  let text: string = '';
  for (let i: number = values.length - 1; i >= 0; i--) {
    text += digitCharOf(values[i]);
  }
  return text.length === 0 ? '0' : text;
}

/** 数字串换进制（长除法，任意精度） */
export function convertDigits(digits: string, fromRadix: number, toRadix: number): string {
  if (digits === '0') {
    return '0';
  }
  let current: number[] = toDigitArray(digits, fromRadix);
  const output: number[] = [];
  while (current.length > 0) {
    const next: number[] = [];
    let remainder: number = 0;
    for (let i: number = current.length - 1; i >= 0; i--) {
      const value: number = remainder * fromRadix + current[i];
      const quotient: number = Math.floor(value / toRadix);
      remainder = value - quotient * toRadix;
      if (next.length > 0 || quotient > 0) {
        next.push(quotient);
      }
    }
    // next 是高位在前，转回最低位在前
    const normalized: number[] = [];
    for (let i: number = next.length - 1; i >= 0; i--) {
      normalized.push(next[i]);
    }
    output.push(remainder);
    current = normalized;
  }
  return fromDigitArray(output);
}

/** 组合带符号与前缀的完整写法 */
function buildPrefixed(negative: boolean, digits: string, radix: number): string {
  const sign: string = negative ? '-' : '';
  return sign + radixPrefix(radix) + digits;
}

/**
 * 进制转换。
 *
 * @param input 输入文本（可带符号、前缀、下划线）
 * @param fromRadix 源进制（2-36）
 * @param toRadix 目标进制（2-36）
 */
export function convertRadix(input: string, fromRadix: number, toRadix: number): RadixConvertResult {
  if (!isValidRadix(fromRadix) || !isValidRadix(toRadix)) {
    return RadixConvertResult.failure(RadixFailureCode.RADIX_OUT_OF_RANGE,
      [String(RADIX_MIN), String(RADIX_MAX)]);
  }
  const parsed: RadixValue = parseRadixValue(input, fromRadix);
  if (!parsed.ok) {
    return RadixConvertResult.failureOf(parsed.failure);
  }
  const digits: string = convertDigits(parsed.digits, fromRadix, toRadix);
  return RadixConvertResult.success(parsed.negative, digits,
    buildPrefixed(parsed.negative, digits, toRadix), false);
}

// ── 位运算：统一走 64 位二进制串 ────────────────────────────────────────

/** 无符号二进制串（去前导零；0 返回 '0'） */
function toBinaryDigits(parsed: RadixValue): string {
  return convertDigits(parsed.digits, parsed.radix, 2);
}

/** 把无符号二进制串补齐/截断到 width 位；返回是否发生了截断 */
class BinaryPadded {
  readonly text: string;
  readonly truncated: boolean;

  constructor(text: string, truncated: boolean) {
    this.text = text;
    this.truncated = truncated;
  }
}

function padToWidth(binary: string, width: number): BinaryPadded {
  if (binary.length > width) {
    return new BinaryPadded(binary.substring(binary.length - width), true);
  }
  let text: string = binary;
  while (text.length < width) {
    text = '0' + text;
  }
  return new BinaryPadded(text, false);
}

/** 二进制串取反（按 width 位） */
function invertBits(bits: string): string {
  let out: string = '';
  for (let i: number = 0; i < bits.length; i++) {
    out += bits.charAt(i) === '0' ? '1' : '0';
  }
  return out;
}

/** 二进制串加 1（模 2^width） */
function addOne(bits: string): string {
  const chars: string[] = [];
  for (let i: number = 0; i < bits.length; i++) {
    chars.push(bits.charAt(i));
  }
  let carry: number = 1;
  for (let i: number = chars.length - 1; i >= 0 && carry > 0; i--) {
    if (chars[i] === '1') {
      chars[i] = '0';
    } else {
      chars[i] = '1';
      carry = 0;
    }
  }
  let out: string = '';
  for (let i: number = 0; i < chars.length; i++) {
    out += chars[i];
  }
  return out;
}

/** 把可能为负的数转成 width 位补码 */
function toTwosComplement(parsed: RadixValue, width: number): BinaryPadded {
  const padded: BinaryPadded = padToWidth(toBinaryDigits(parsed), width);
  if (!parsed.negative) {
    return padded;
  }
  return new BinaryPadded(addOne(invertBits(padded.text)), padded.truncated);
}

/** 去掉二进制串的前导零；全零返回 '0' */
function trimBinary(bits: string): string {
  let index: number = 0;
  while (index < bits.length - 1 && bits.charAt(index) === '0') {
    index++;
  }
  return bits.substring(index);
}

/** 补码串 → 有符号数值（负数为「取反加一」的幅值） */
function fromTwosComplement(bits: string): RadixValue {
  if (bits.charAt(0) === '1') {
    const magnitude: string = addOne(invertBits(bits));
    return RadixValue.success(true, 2, trimBinary(magnitude));
  }
  return RadixValue.success(false, 2, trimBinary(bits));
}

/** 二进制串 → 指定进制的数字串 */
function binaryToRadix(bits: string, radix: number): string {
  return convertDigits(trimBinary(bits), 2, radix);
}

/** 位运算操作名是否合法 */
export function isBitwiseOperationName(name: string): boolean {
  return name === NGFBitwiseOperation.AND || name === NGFBitwiseOperation.OR
    || name === NGFBitwiseOperation.XOR || name === NGFBitwiseOperation.NOT
    || name === NGFBitwiseOperation.SHIFT_LEFT || name === NGFBitwiseOperation.SHIFT_RIGHT;
}

/**
 * 按 64 位有符号语义做位运算。
 *
 * @param leftText 左操作数（`NOT` 只用它）
 * @param rightText 右操作数（`NOT` 忽略；移位操作只用它的移位位数）
 * @param operation 操作名（取值见 {@link NGFBitwiseOperation}）
 * @param radix 操作数与结果共用的进制（2-36）
 * @param shift 移位位数（0-63），仅移位操作使用
 */
export function bitwiseOperation(leftText: string, rightText: string, operation: string,
  radix: number, shift: number): RadixConvertResult {
  if (!isValidRadix(radix)) {
    return RadixConvertResult.failure(RadixFailureCode.RADIX_OUT_OF_RANGE,
      [String(RADIX_MIN), String(RADIX_MAX)]);
  }
  if (!isBitwiseOperationName(operation)) {
    return RadixConvertResult.failure(RadixFailureCode.UNSUPPORTED_OPERATION, [operation]);
  }
  const width: number = BITWISE_WIDTH;
  const left: RadixValue = parseRadixValue(leftText, radix);
  if (!left.ok) {
    return RadixConvertResult.failureOf(left.failure);
  }
  const leftBits: BinaryPadded = toTwosComplement(left, width);
  let truncated: boolean = leftBits.truncated;

  if (operation === NGFBitwiseOperation.NOT) {
    const flipped: RadixValue = fromTwosComplement(invertBits(leftBits.text));
    const digits: string = binaryToRadix(flipped.digits, radix);
    return RadixConvertResult.success(flipped.negative, digits,
      buildPrefixed(flipped.negative, digits, radix), truncated);
  }

  if (operation === NGFBitwiseOperation.SHIFT_LEFT || operation === NGFBitwiseOperation.SHIFT_RIGHT) {
    if (shift < 0 || shift >= width) {
      return RadixConvertResult.failure(RadixFailureCode.SHIFT_OUT_OF_RANGE,
        ['0', String(width - 1)]);
    }
    const bits: string = leftBits.text;
    let shifted: string = '';
    if (operation === NGFBitwiseOperation.SHIFT_LEFT) {
      // 左移：低位补 0，移出去的高位就是被丢弃的部分——把它显式记成 truncated
      const overflow: boolean = shift > 0 && trimBinary(bits.substring(0, shift)) !== '0';
      truncated = truncated || overflow;
      shifted = bits.substring(shift) + '0'.repeat(shift);
    } else {
      // 算术右移：最高位（符号位）保持不变
      const signBit: string = bits.charAt(0);
      shifted = signBit.repeat(shift) + bits.substring(0, width - shift);
    }
    const value: RadixValue = fromTwosComplement(shifted);
    const digits: string = binaryToRadix(value.digits, radix);
    return RadixConvertResult.success(value.negative, digits,
      buildPrefixed(value.negative, digits, radix), truncated);
  }

  const right: RadixValue = parseRadixValue(rightText, radix);
  if (!right.ok) {
    return RadixConvertResult.failureOf(right.failure);
  }
  const rightBits: BinaryPadded = toTwosComplement(right, width);
  truncated = truncated || rightBits.truncated;

  let resultBits: string = '';
  for (let i: number = 0; i < width; i++) {
    const a: string = leftBits.text.charAt(i);
    const b: string = rightBits.text.charAt(i);
    if (operation === NGFBitwiseOperation.AND) {
      resultBits += a === '1' && b === '1' ? '1' : '0';
    } else if (operation === NGFBitwiseOperation.OR) {
      resultBits += a === '1' || b === '1' ? '1' : '0';
    } else {
      resultBits += a !== b ? '1' : '0';
    }
  }
  const value: RadixValue = fromTwosComplement(resultBits);
  const digits: string = binaryToRadix(value.digits, radix);
  return RadixConvertResult.success(value.negative, digits,
    buildPrefixed(value.negative, digits, radix), truncated);
}
