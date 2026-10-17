/**
 * 文本行工具的纯逻辑实现：去重 / 排序 / 统计。
 *
 * ## 为什么是「行数组」而不是一个结果串
 *
 * 去重、排序、统计三件事的输出形态不同：去重与排序产出**行列表**，
 * 统计产出**数字组**。用一个「行数组 + 统计对象」的结果类，页面可以
 * 按需渲染（排序变了统计不用重算），也方便单测逐项断言。
 *
 * ## 排序为什么用「本地化比较」做次要键
 *
 * 排序主键由用户选（原序/字典序/长度），但「字典序」里 a 与 A 谁在前
 * 取决于比较函数。这里用 localeCompare 做次级稳定化——与用户在系统
 * 文件管理器里看到的排序一致，而不是按码位排（Z < a 的反直觉结果）。
 *
 * @module tools/text-toolkit/TextToolkit
 */

/** 排序模式 */
export enum LineSortMode {
  /** 保持原顺序（用于「只去重不排序」） */
  ORIGINAL = 'original',
  /** 字典序（本地化比较，A/a 相邻） */
  LEXICAL = 'lexical',
  /** 按行长升序 */
  LENGTH_ASC = 'length_asc',
  /** 按行长降序 */
  LENGTH_DESC = 'length_desc',
  /** 反转 */
  REVERSE = 'reverse'
}

/** 失败原因码 */
export enum TextToolkitFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  /** 全是空白行（没有可处理的实质内容） */
  NO_CONTENT = 'no_content'
}

/** 一次失败的原因与文案参数 */
export class TextToolkitFailure {
  readonly code: TextToolkitFailureCode;
  readonly args: Array<string>;

  constructor(code: TextToolkitFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 文本统计 */
export class TextStats {
  /** 总行数（含空行） */
  readonly totalLines: number;
  /** 非空行数 */
  readonly nonEmptyLines: number;
  /** 空行数 */
  readonly emptyLines: number;
  /** 字符数（不含换行） */
  readonly chars: number;
  /** 去掉空白后的字符数 */
  readonly charsNoSpace: number;
  /** 词数（按空白切分） */
  readonly words: number;
  /** CRLF 行数（行尾风格提示用） */
  readonly crlfLines: number;
  /** LF 行数 */
  readonly lfLines: number;

  constructor(totalLines: number, nonEmptyLines: number, emptyLines: number,
    chars: number, charsNoSpace: number, words: number,
    crlfLines: number, lfLines: number) {
    this.totalLines = totalLines;
    this.nonEmptyLines = nonEmptyLines;
    this.emptyLines = emptyLines;
    this.chars = chars;
    this.charsNoSpace = charsNoSpace;
    this.words = words;
    this.crlfLines = crlfLines;
    this.lfLines = lfLines;
  }
}

/** 处理结果 */
export class TextToolkitResult {
  readonly ok: boolean;
  readonly failure: TextToolkitFailure;
  /** 处理后的行 */
  readonly lines: Array<string>;
  /** 被去掉的重复行数（排序模式不影响它） */
  readonly removedDuplicates: number;
  readonly stats: TextStats;

  constructor(ok: boolean, failure: TextToolkitFailure, lines: Array<string>,
    removedDuplicates: number, stats: TextStats) {
    this.ok = ok;
    this.failure = failure;
    this.lines = lines;
    this.removedDuplicates = removedDuplicates;
    this.stats = stats;
  }
}

/** 按行切分：把 CR-LF 与 LF 统一成行数组；末尾**所有**空行丢弃（编辑器惯例）。
 *
 * 第一版只 pop 一个末尾空行——'a 换行 换行' 切出来是 [a, '', '']，
 * pop 一次还剩一个空行，长度变成 2。改成 while 循环丢光末尾空行。
 */
export function splitLines(input: string): Array<string> {
  const normalized: string = input.split(String.fromCharCode(13) + String.fromCharCode(10)).join(String.fromCharCode(10));
  const raw: Array<string> = normalized.split(String.fromCharCode(10));
  while (raw.length > 1 && raw[raw.length - 1].length === 0) {
    raw.pop();
  }
  return raw;
}

/** 统计：独立导出，页面可以在不动行的场景下只刷新统计 */
export function computeStats(lines: Array<string>, lineEndings: Array<string>): TextStats {
  let total: number = lines.length;
  let nonEmpty: number = 0;
  let chars: number = 0;
  let charsNoSpace: number = 0;
  let words: number = 0;
  for (let i = 0; i < lines.length; i++) {
    const line: string = lines[i];
    if (line.trim().length > 0) {
      nonEmpty++;
    }
    chars = chars + line.length;
    const noSpace: string = line.split(' ').join('').split(String.fromCharCode(9)).join('');
    charsNoSpace = charsNoSpace + noSpace.length;
    const compact: string = line.trim().split(String.fromCharCode(9)).join(' ');
    const wordsInLine: Array<string> = compact.length === 0 ? [] : compact.split(' ');
    words = words + wordsInLine.length;
  }
  let crlf: number = 0;
  let lf: number = 0;
  for (let i = 0; i < lineEndings.length; i++) {
    if (lineEndings[i] === '\r\n') {
      crlf++;
    } else {
      lf++;
    }
  }
  return new TextStats(total, nonEmpty, total - nonEmpty, chars, charsNoSpace, words, crlf, lf);
}

/** 检测每行的行尾（CRLF 计数用；最后无换行的行算 LF） */
export function detectLineEndings(input: string): Array<string> {
  const out: Array<string> = [];
  for (let i = 0; i < input.length; i++) {
    const ch: string = input.charAt(i);
    if (ch === String.fromCharCode(10)) {
      const prev: string = i > 0 ? input.charAt(i - 1) : '';
      out.push(prev === String.fromCharCode(13) ? String.fromCharCode(13) + String.fromCharCode(10) : String.fromCharCode(10));
    }
  }
  return out;
}

/**
 * 主入口：去重（可选保留首次出现）+ 排序 + 统计。
 * 空白行默认剔除（去重场景里它们没有意义）；统计基于**剔除后**的行。
 */
export function processLines(input: string, sortMode: LineSortMode,
  dedupe: boolean, trimLines: boolean, dropEmpty: boolean): TextToolkitResult {
  const text: string = input;
  if (text.trim().length === 0) {
    return new TextToolkitResult(false,
      new TextToolkitFailure(TextToolkitFailureCode.EMPTY_INPUT, []),
      [], 0, computeStats([], []));
  }
  const endings: Array<string> = detectLineEndings(text);
  let lines: Array<string> = splitLines(text);
  if (trimLines) {
    const trimmed: Array<string> = [];
    for (let i = 0; i < lines.length; i++) {
      trimmed.push(lines[i].trim());
    }
    lines = trimmed;
  }
  if (dropEmpty) {
    const kept: Array<string> = [];
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].length > 0) {
        kept.push(lines[i]);
      }
    }
    lines = kept;
  }
  if (lines.length === 0) {
    return new TextToolkitResult(false,
      new TextToolkitFailure(TextToolkitFailureCode.NO_CONTENT, []),
      [], 0, computeStats([], []));
  }
  let removed: number = 0;
  if (dedupe) {
    const seen: Map<string, boolean> = new Map<string, boolean>();
    const kept: Array<string> = [];
    for (let i = 0; i < lines.length; i++) {
      const line: string = lines[i];
      if (seen.has(line)) {
        removed++;
      } else {
        seen.set(line, true);
        kept.push(line);
      }
    }
    lines = kept;
  }
  if (sortMode === LineSortMode.LEXICAL) {
    const copy: Array<string> = lines.slice();
    copy.sort((a: string, b: string): number => {
      const cmp: number = a.localeCompare(b);
      if (cmp !== 0) {
        return cmp;
      }
      return a < b ? -1 : a > b ? 1 : 0;
    });
    lines = copy;
  } else if (sortMode === LineSortMode.LENGTH_ASC) {
    const copy: Array<string> = lines.slice();
    copy.sort((a: string, b: string): number => a.length - b.length);
    lines = copy;
  } else if (sortMode === LineSortMode.LENGTH_DESC) {
    const copy: Array<string> = lines.slice();
    copy.sort((a: string, b: string): number => b.length - a.length);
    lines = copy;
  } else if (sortMode === LineSortMode.REVERSE) {
    const copy: Array<string> = lines.slice();
    copy.reverse();
    lines = copy;
  }
  return new TextToolkitResult(true,
    new TextToolkitFailure(TextToolkitFailureCode.NONE, []),
    lines, removed, computeStats(lines, endings));
}
