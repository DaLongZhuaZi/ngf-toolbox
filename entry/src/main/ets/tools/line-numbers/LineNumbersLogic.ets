/**
 * 行号添加器的纯逻辑实现。
 *
 * ## 选项
 *
 * 前缀格式（点/方括号/冒号）、起始行号、行号右对齐补空格。空行也加行号。
 *
 * @module tools/line-numbers/LineNumbersLogic
 */

/** 失败原因码 */
export enum LineNumFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input'
}

/** 行号格式 */
export enum LineNumStyle {
  DOT = 'dot',
  BRACKET = 'bracket',
  COLON = 'colon'
}

/** 一次失败的原因与文案参数 */
export class LineNumFailure {
  readonly code: LineNumFailureCode;
  readonly args: Array<string>;

  constructor(code: LineNumFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}
/** 结果 */
export class LineNumResult {
  readonly ok: boolean;
  readonly failure: LineNumFailure;
  readonly output: string;
  readonly lineCount: number;

  constructor(ok: boolean, failure: LineNumFailure, output: string, lineCount: number) {
    this.ok = ok;
    this.failure = failure;
    this.output = output;
    this.lineCount = lineCount;
  }
}

const SPACE: string = String.fromCharCode(32);
const NEWLINE: string = String.fromCharCode(10);

/** 前缀构造：样式 + 右对齐行号 */
function makePrefix(style: LineNumStyle, num: number, maxNum: number): string {
  const maxLen: string = String(maxNum);
  let numStr: string = String(num);
  while (numStr.length < maxLen.length) {
    numStr = SPACE + numStr;
  }
  if (style === LineNumStyle.BRACKET) {
    return '[' + numStr + ']' + SPACE;
  }
  if (style === LineNumStyle.COLON) {
    return 'L' + numStr + ':' + SPACE;
  }
  return numStr + '.' + SPACE;
}
/** 主入口 */
export function addLineNumbers(input: string, style: LineNumStyle,
  startNumber: number): LineNumResult {
  if (input.length === 0) {
    return new LineNumResult(false, new LineNumFailure(LineNumFailureCode.EMPTY_INPUT, []), '', 0);
  }
  const rawLines: Array<string> = input.split(NEWLINE);
  const maxNum: number = startNumber + rawLines.length - 1;
  const out: Array<string> = [];
  for (let i = 0; i < rawLines.length; i++) {
    const num: number = startNumber + i;
    out.push(makePrefix(style, num, maxNum) + rawLines[i]);
  }
  return new LineNumResult(true, new LineNumFailure(LineNumFailureCode.NONE, []),
    out.join(NEWLINE), rawLines.length);
}