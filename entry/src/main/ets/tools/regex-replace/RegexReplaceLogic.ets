/**
 * 正则替换预览的纯逻辑实现。
 *
 * ## 替换语义
 *
 * 支持替换串里的 $1-$9 捕获组引用。输出替换后全文 + 每次匹配的原文与位置清单。
 * 标志只允许 g/i/m（其余剥掉）。空匹配防死循环。
 *
 * @module tools/regex-replace/RegexReplaceLogic
 */

/** 失败原因码 */
export enum RegexReplaceFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  EMPTY_PATTERN = 'empty_pattern',
  BAD_REGEX = 'bad_regex'
}

/** 一次失败的原因与文案参数 */
export class RegexReplaceFailure {
  readonly code: RegexReplaceFailureCode;
  readonly args: Array<string>;

  constructor(code: RegexReplaceFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 一次匹配 */
export class RegexMatchItem {
  readonly matched: string;
  readonly index: number;

  constructor(matched: string, index: number) {
    this.matched = matched;
    this.index = index;
  }
}

/** 结果 */
export class RegexReplaceResult {
  readonly ok: boolean;
  readonly failure: RegexReplaceFailure;
  readonly replaced: string;
  readonly matches: Array<RegexMatchItem>;
  /** 是否应用了 g 标志 */
  readonly global: boolean;

  constructor(ok: boolean, failure: RegexReplaceFailure, replaced: string,
    matches: Array<RegexMatchItem>, global: boolean) {
    this.ok = ok;
    this.failure = failure;
    this.replaced = replaced;
    this.matches = matches;
    this.global = global;
  }
}

/** 主入口 */
export function replacePreview(input: string, pattern: string, flags: string,
  replacement: string): RegexReplaceResult {
  if (input.length === 0) {
    return new RegexReplaceResult(false,
      new RegexReplaceFailure(RegexReplaceFailureCode.EMPTY_INPUT, []), '', [], false);
  }
  if (pattern.trim().length === 0) {
    return new RegexReplaceResult(false,
      new RegexReplaceFailure(RegexReplaceFailureCode.EMPTY_PATTERN, []), '', [], false);
  }
  let cleanFlags: string = '';
  if (flags.indexOf('g') >= 0) { cleanFlags = cleanFlags + 'g'; }
  if (flags.indexOf('i') >= 0) { cleanFlags = cleanFlags + 'i'; }
  if (flags.indexOf('m') >= 0) { cleanFlags = cleanFlags + 'm'; }
  let regex: RegExp;
  try {
    regex = new RegExp(pattern, cleanFlags);
  } catch (e) {
    return new RegexReplaceResult(false,
      new RegexReplaceFailure(RegexReplaceFailureCode.BAD_REGEX, []), '', [], false);
  }
  const matches: Array<RegexMatchItem> = [];
  const globalMode: boolean = cleanFlags.indexOf('g') >= 0;
  let cursor: number = 0;
  while (cursor <= input.length) {
    regex.lastIndex = 0;
    const slice: string = input.substring(cursor);
    const m: RegExpExecArray | null = regex.exec(slice);
    if (m === null) {
      break;
    }
    matches.push(new RegexMatchItem(m[0], cursor + m.index));
    if (m[0].length === 0) {
      cursor = cursor + m.index + 1;
    } else {
      cursor = cursor + m.index + m[0].length;
    }
    if (!globalMode) {
      break;
    }
  }
  const replaced: string = input.replace(regex, replacement);
  return new RegexReplaceResult(true, new RegexReplaceFailure(RegexReplaceFailureCode.NONE, []),
    replaced, matches, globalMode);
}