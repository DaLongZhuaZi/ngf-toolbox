/**
 * Markdown 目录生成的纯逻辑实现。
 *
 * ## 规则
 *
 * 扫描行首的 #/##/###（最多三级），跳过代码块（``` 围栏）内的行；
 * 生成缩进列表 + GitHub 风格锚点（小写、空格转横线、去标点）。
 *
 * @module tools/markdown-toc/MarkdownTocLogic
 */

/** 失败原因码 */
export enum TocFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  NO_HEADINGS = 'no_headings'
}

/** 一次失败的原因与文案参数 */
export class TocFailure {
  readonly code: TocFailureCode;
  readonly args: Array<string>;

  constructor(code: TocFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 一条目录项 */
export class TocItem {
  readonly level: number;
  readonly text: string;
  readonly anchor: string;

  constructor(level: number, text: string, anchor: string) {
    this.level = level;
    this.text = text;
    this.anchor = anchor;
  }
}

/** 结果 */
export class TocResult {
  readonly ok: boolean;
  readonly failure: TocFailure;
  readonly items: Array<TocItem>;
  readonly markdown: string;

  constructor(ok: boolean, failure: TocFailure, items: Array<TocItem>, markdown: string) {
    this.ok = ok;
    this.failure = failure;
    this.items = items;
    this.markdown = markdown;
  }
}

const HASH: string = String.fromCharCode(35);
const SPACE: string = String.fromCharCode(32);
const DASH: string = String.fromCharCode(45);
const NEWLINE: string = String.fromCharCode(10);
const FENCE: string = String.fromCharCode(96) + String.fromCharCode(96) + String.fromCharCode(96);

/** GitHub 风格 slug：小写、空格转横线、去标点、保留中文与连字符 */
export function slugify(text: string): string {
  let out: string = '';
  for (let i = 0; i < text.length; i++) {
    const ch: string = text.charAt(i);
    const lower: string = ch.toLowerCase();
    const isAlnum: boolean = (lower >= 'a' && lower <= 'z') || (ch >= '0' && ch <= '9');
    if (isAlnum) {
      out = out + lower;
    } else if (ch === DASH) {
      out = out + DASH;
    } else if (ch === SPACE) {
      out = out + DASH;
    } else if (ch.charCodeAt(0) > 127) {
      // 非ASCII（中文等）保留
      out = out + ch;
    }
    // 其余标点丢弃
  }
  return out;
}

/** 主入口 */
export function buildToc(input: string): TocResult {
  if (input.trim().length === 0) {
    return new TocResult(false, new TocFailure(TocFailureCode.EMPTY_INPUT, []), [], '');
  }
  const rawLines: Array<string> = input.split(NEWLINE);
  const items: Array<TocItem> = [];
  let inFence: boolean = false;
  for (let i = 0; i < rawLines.length; i++) {
    const line: string = rawLines[i];
    if (line.trim().indexOf(FENCE) === 0) {
      inFence = !inFence;
      continue;
    }
    if (inFence) {
      continue;
    }
    if (line.charAt(0) !== HASH) {
      continue;
    }
    let level: number = 0;
    while (level < line.length && line.charAt(level) === HASH) {
      level++;
    }
    if (level > 3) {
      continue;
    }
    const text: string = line.substring(level).trim();
    if (text.length === 0) {
      continue;
    }
    items.push(new TocItem(level, text, slugify(text)));
  }
  if (items.length === 0) {
    return new TocResult(false, new TocFailure(TocFailureCode.NO_HEADINGS, []), [], '');
  }
  let md: string = '';
  for (let i = 0; i < items.length; i++) {
    const indent: string = items[i].level === 1 ? '' :
      (items[i].level === 2 ? SPACE + SPACE : SPACE + SPACE + SPACE + SPACE);
    md = md + (i > 0 ? NEWLINE : '') + indent + '- [' + items[i].text + '](#' + items[i].anchor + ')';
  }
  return new TocResult(true, new TocFailure(TocFailureCode.NONE, []), items, md);
}