/**
 * 文本自动换行的纯逻辑实现。
 *
 * ## 规则
 *
 * 按空格分词后贪心装行（词间保留单空格）；单个超长词强制断到行宽；
 * 保留显式换行。宽度 10-200。
 *
 * @module tools/word-wrap/WordWrapLogic
 */

/** 失败原因码 */
export enum WrapFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  WIDTH_OUT_OF_RANGE = 'width_out_of_range'
}

/** 一次失败的原因与文案参数 */
export class WrapFailure {
  readonly code: WrapFailureCode;
  readonly args: Array<string>;

  constructor(code: WrapFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 结果 */
export class WrapResult {
  readonly ok: boolean;
  readonly failure: WrapFailure;
  readonly output: string;
  readonly lineCount: number;

  constructor(ok: boolean, failure: WrapFailure, output: string, lineCount: number) {
    this.ok = ok;
    this.failure = failure;
    this.output = output;
    this.lineCount = lineCount;
  }
}
const SPACE: string = String.fromCharCode(32);
const NEWLINE: string = String.fromCharCode(10);
const MIN_WIDTH: number = 10;
const MAX_WIDTH: number = 200;

/** 单词数组转行（贪心装行 + 超长词强制断） */
function wrapParagraph(words: Array<string>, width: number, outLines: Array<string>): void {
  let current: string = '';
  for (let w = 0; w < words.length; w++) {
    let word: string = words[w];
    // 超长词强制断到行宽
    while (word.length > width) {
      if (current.trim().length > 0) {
        outLines.push(current.trim());
        current = '';
      }
      outLines.push(word.substring(0, width));
      word = word.substring(width);
    }
    if (word.length === 0) {
      continue;
    }
    if (current.length === 0) {
      current = word;
    } else if (current.length + 1 + word.length <= width) {
      current = current + SPACE + word;
    } else {
      outLines.push(current);
      current = word;
    }
  }
  if (current.trim().length > 0) {
    outLines.push(current.trim());
  }
}

/** 主入口 */
export function wrapText(input: string, widthText: string): WrapResult {
  if (input.trim().length === 0) {
    return new WrapResult(false, new WrapFailure(WrapFailureCode.EMPTY_INPUT, []), '', 0);
  }
  const width: number = parseInt(widthText, 10);
  if (isNaN(width) || width < MIN_WIDTH || width > MAX_WIDTH) {
    return new WrapResult(false,
      new WrapFailure(WrapFailureCode.WIDTH_OUT_OF_RANGE, [String(MIN_WIDTH), String(MAX_WIDTH)]), '', 0);
  }
  const outLines: Array<string> = [];
  const paragraphs: Array<string> = input.split(NEWLINE);
  for (let p = 0; p < paragraphs.length; p++) {
    const para: string = paragraphs[p];
    if (para.trim().length === 0) {
      outLines.push('');
      continue;
    }
    const words: Array<string> = para.trim().split(SPACE);
    wrapParagraph(words, width, outLines);
  }
  return new WrapResult(true, new WrapFailure(WrapFailureCode.NONE, []),
    outLines.join(NEWLINE), outLines.length);
}