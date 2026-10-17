/**
 * ASCII 注释分隔线/横幅生成的纯逻辑实现。
 *
 * ## 样式
 *
 * line = 横线；banner = 文本居中夹在横线之间；box = 文本带边框。
 * 注释前缀按语言：c 系双斜线、脚本井号、SQL 双横线。
 *
 * @module tools/ascii-line/AsciiLineLogic
 */

/** 失败原因码 */
export enum AsciiFailureCode {
  NONE = 'none',
  EMPTY_TEXT = 'empty_text',
  WIDTH_OUT_OF_RANGE = 'width_out_of_range'
}

/** 一次失败的原因与文案参数 */
export class AsciiFailure {
  readonly code: AsciiFailureCode;
  readonly args: Array<string>;

  constructor(code: AsciiFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 结果 */
export class AsciiResult {
  readonly ok: boolean;
  readonly failure: AsciiFailure;
  readonly output: string;

  constructor(ok: boolean, failure: AsciiFailure, output: string) {
    this.ok = ok;
    this.failure = failure;
    this.output = output;
  }
}

const EQ: string = String.fromCharCode(61);
const STAR: string = String.fromCharCode(42);
const HASH: string = String.fromCharCode(35);
const TILDE: string = String.fromCharCode(126);
const DASH: string = String.fromCharCode(45);
const SPACE: string = String.fromCharCode(32);
const NEWLINE: string = String.fromCharCode(10);
const MIN_WIDTH: number = 10;
const MAX_WIDTH: number = 120;

/** 填充字符：eq/star/hash/tilde/dash */
function fillCharOf(style: string): string {
  if (style === 'star') {
    return STAR;
  }
  if (style === 'hash') {
    return HASH;
  }
  if (style === 'tilde') {
    return TILDE;
  }
  if (style === 'dash') {
    return DASH;
  }
  return EQ;
}

function repeat(ch: string, times: number): string {
  let out: string = '';
  for (let i = 0; i < times; i++) {
    out = out + ch;
  }
  return out;
}

/** 注释前缀：c=双斜线，hash=井号，sql=双横线 */
function prefixOf(commentStyle: string): string {
  if (commentStyle === 'hash') {
    return HASH + SPACE;
  }
  if (commentStyle === 'sql') {
    return DASH + DASH + SPACE;
  }
  return '/' + '/' + SPACE;
}

/** 居中文本（奇数差给左侧） */
function centerText(text: string, width: number): string {
  const total: number = width - text.length;
  if (total <= 0) {
    return text;
  }
  const left: number = Math.floor(total / 2);
  return repeat(SPACE, left) + text + repeat(SPACE, total - left);
}

/**
 * 主入口。
 *
 * @param style eq/star/hash/tilde/dash
 * @param kind line/banner/box
 * @param commentStyle c/hash/sql
 * @param text banner/box 的文本（line 样式忽略）
 */
export function buildAscii(style: string, kind: string, commentStyle: string,
  widthText: string, text: string): AsciiResult {
  const width: number = parseInt(widthText, 10);
  if (isNaN(width) || width < MIN_WIDTH || width > MAX_WIDTH) {
    return new AsciiResult(false,
      new AsciiFailure(AsciiFailureCode.WIDTH_OUT_OF_RANGE, [String(MIN_WIDTH), String(MAX_WIDTH)]), '');
  }
  const fill: string = fillCharOf(style);
  const prefix: string = prefixOf(commentStyle);
  const outLines: Array<string> = [];
  if (kind === 'line') {
    outLines.push(prefix + repeat(fill, width));
  } else if (kind === 'banner') {
    const t: string = text.trim();
    if (t.length === 0) {
      return new AsciiResult(false, new AsciiFailure(AsciiFailureCode.EMPTY_TEXT, []), '');
    }
    outLines.push(prefix + repeat(fill, width));
    outLines.push(prefix + centerText(t, width));
    outLines.push(prefix + repeat(fill, width));
  } else if (kind === 'box') {
    const t: string = text.trim();
    if (t.length === 0) {
      return new AsciiResult(false, new AsciiFailure(AsciiFailureCode.EMPTY_TEXT, []), '');
    }
    const inner: number = width - 4;
    const padded: string = centerText(t, inner);
    outLines.push(prefix + '+' + repeat(DASH, inner) + '+');
    outLines.push(prefix + '| ' + padded + ' |');
    outLines.push(prefix + '+' + repeat(DASH, inner) + '+');
  } else {
    outLines.push(prefix + repeat(fill, width));
  }
  return new AsciiResult(true, new AsciiFailure(AsciiFailureCode.NONE, []), outLines.join(NEWLINE));
}