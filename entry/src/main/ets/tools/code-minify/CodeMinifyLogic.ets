/**
 * 代码压缩预览的纯逻辑实现（文本级：去注释与压空白，字符串字面量保护）。
 *
 * ## 规则
 *
 * 剥离双斜线行注释与块注释（引号内的不算）；连续空白压成单空格；
 * 引号内的内容原样保留。不做 AST 级压缩（不改标识符与语义）。
 *
 * @module tools/code-minify/CodeMinifyLogic
 */

/** 失败原因码 */
export enum MinifyFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  UNCLOSED_BLOCK = 'unclosed_block'
}

/** 一次失败的原因与文案参数 */
export class MinifyFailure {
  readonly code: MinifyFailureCode;
  readonly args: Array<string>;

  constructor(code: MinifyFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 结果 */
export class MinifyResult {
  readonly ok: boolean;
  readonly failure: MinifyFailure;
  readonly output: string;
  /** 原字符数 */
  readonly originalLength: number;
  /** 压缩后字符数 */
  readonly minifiedLength: number;

  constructor(ok: boolean, failure: MinifyFailure, output: string,
    originalLength: number, minifiedLength: number) {
    this.ok = ok;
    this.failure = failure;
    this.output = output;
    this.originalLength = originalLength;
    this.minifiedLength = minifiedLength;
  }
}

const SLASH: string = String.fromCharCode(47);
const STAR: string = String.fromCharCode(42);
const SQUOTE: string = String.fromCharCode(39);
const DQUOTE: string = String.fromCharCode(34);
const SPACE: string = String.fromCharCode(32);
const NEWLINE: string = String.fromCharCode(10);
const TAB: string = String.fromCharCode(9);
const CR: string = String.fromCharCode(13);

/** 主入口 */
export function minifyCode(input: string): MinifyResult {
  if (input.trim().length === 0) {
    return new MinifyResult(false, new MinifyFailure(MinifyFailureCode.EMPTY_INPUT, []), '', 0, 0);
  }
  let out: string = '';
  let i: number = 0;
  const n: number = input.length;
  let quote: string = '';
  while (i < n) {
    const ch: string = input.charAt(i);
    if (quote.length > 0) {
      out = out + ch;
      if (ch === quote) {
        quote = '';
      }
      i++;
      continue;
    }
    if (ch === SQUOTE || ch === DQUOTE) {
      quote = ch;
      out = out + ch;
      i++;
      continue;
    }
    if (ch === SLASH && i + 1 < n && input.charAt(i + 1) === SLASH) {
      while (i < n && input.charAt(i) !== NEWLINE) {
        i++;
      }
      continue;
    }
    if (ch === SLASH && i + 1 < n && input.charAt(i + 1) === STAR) {
      const closeToken: string = STAR + SLASH;
      const close: number = input.indexOf(closeToken, i + 2);
      if (close < 0) {
        return new MinifyResult(false, new MinifyFailure(MinifyFailureCode.UNCLOSED_BLOCK, []), '', input.length, 0);
      }
      i = close + 2;
      continue;
    }
    out = out + ch;
    i++;
  }
  let squeezed: string = '';
  let inBlank: boolean = false;
  for (let i2 = 0; i2 < out.length; i2++) {
    const c: string = out.charAt(i2);
    const isBlank: boolean = c === SPACE || c === NEWLINE || c === TAB || c === CR;
    if (isBlank) {
      inBlank = true;
      continue;
    }
    if (inBlank) {
      squeezed = squeezed + SPACE;
      inBlank = false;
    }
    squeezed = squeezed + c;
  }
  const trimmed: string = squeezed.trim();
  return new MinifyResult(true, new MinifyFailure(MinifyFailureCode.NONE, []),
    trimmed, input.length, trimmed.length);
}