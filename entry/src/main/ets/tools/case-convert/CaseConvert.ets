/**
 * 字符串命名风格转换的纯逻辑实现。
 *
 * ## 切词是唯一的核心
 *
 * camelCase / snake_case / kebab-case / PascalCase / SCREAMING_CASE 之间的转换，
 * 难点全在**把输入先切成词**。这里用一条统一规则：
 * 在「小写→大写」「字母→数字」「数字→字母」「任意→非字母数字」四个边界切一刀，
 * 得到词数组后再按目标风格拼回去。这样 `HTTPServer2` → [HTTP, Server, 2]，
 * `user_name` → [user, name]，不需要针对每种输入风格写识别器。
 *
 * ## 全大写词的归属
 *
 * `HTTPServer` 里的 HTTP 是一个词（连续大写后跟大写+小写才断开），
 * 而 `HTTPServer`.toLowerCase() 再按大小写边界切会把它切碎。
 * 所以切词直接在**原始输入**上做，不做预小写化。
 *
 * @module tools/case-convert/CaseConvert
 */

/** 支持的目标风格 */
export enum NameCaseStyle {
  CAMEL = 'camel',
  PASCAL = 'pascal',
  SNAKE = 'snake',
  SCREAMING = 'screaming',
  KEBAB = 'kebab',
  /** 点分（Java properties / INI 键常用） */
  DOT = 'dot'
}

/** 失败原因码 */
export enum CaseFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  /** 切不出任何词（输入全是符号/空白） */
  NO_WORDS = 'no_words'
}

/** 一次失败的原因与文案参数 */
export class CaseFailure {
  readonly code: CaseFailureCode;
  readonly args: Array<string>;

  constructor(code: CaseFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 转换结果：每个风格一行，UI 直接渲染 */
export class CaseConvertResult {
  readonly ok: boolean;
  readonly failure: CaseFailure;
  /** 与 NameCaseStyle 枚举顺序一致的六个结果串 */
  readonly camel: string;
  readonly pascal: string;
  readonly snake: string;
  readonly screaming: string;
  readonly kebab: string;
  readonly dot: string;

  constructor(ok: boolean, failure: CaseFailure,
    camel: string, pascal: string, snake: string,
    screaming: string, kebab: string, dot: string) {
    this.ok = ok;
    this.failure = failure;
    this.camel = camel;
    this.pascal = pascal;
    this.snake = snake;
    this.screaming = screaming;
    this.kebab = kebab;
    this.dot = dot;
  }
}

function isAsciiLetter(ch: string): boolean {
  return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z');
}

function isAsciiDigit(ch: string): boolean {
  return ch >= '0' && ch <= '9';
}

/**
 * 把原始输入切成词数组。
 * 边界规则：小写→大写、字母→数字、数字→字母、非字母数字两侧。
 * 连续大写后跟「大写+小写」时，最后一个大写归下一个词（HTTPServer → HTTP|Server）。
 */
export function splitNameWords(input: string): Array<string> {
  const words: Array<string> = [];
  let current: string = '';
  const text: string = input.trim();
  for (let i = 0; i < text.length; i++) {
    const ch: string = text.charAt(i);
    const isAlnum: boolean = isAsciiLetter(ch) || isAsciiDigit(ch);
    if (!isAlnum) {
      if (current.length > 0) {
        words.push(current);
        current = '';
      }
      continue;
    }
    if (current.length === 0) {
      current = ch;
      continue;
    }
    const prev: string = current.charAt(current.length - 1);
    const prevLower: boolean = isAsciiLetter(prev) && prev === prev.toLowerCase();
    const prevDigit: boolean = isAsciiDigit(prev);
    const curUpper: boolean = isAsciiLetter(ch) && ch === ch.toUpperCase();
    const curDigit: boolean = isAsciiDigit(ch);
    let boundary: boolean = false;
    if (prevLower && curUpper) {
      boundary = true;
    } else if (prevDigit !== curDigit) {
      boundary = true;
    } else if (!prevLower && !prevDigit && curUpper && isAsciiLetter(ch)) {
      // 连续大写：只有「当前是大写、下一个是小写」才在当前字符前断词
      // （HTTPServer 的 S|Server）。看下一个字符，别看有没有下一个字符——
      // 把「没有下一个字符」当断点是第一版写错的地方（USER_NAME → USE|R|NAM|E）。
      const nextCh: string = i + 1 < text.length ? text.charAt(i + 1) : '';
      const nextLower: boolean = nextCh !== '' && isAsciiLetter(nextCh) && nextCh === nextCh.toLowerCase();
      if (nextLower) {
        boundary = true;
      }
    }
    if (boundary) {
      words.push(current);
      current = ch;
    } else {
      current = current + ch;
    }
  }
  if (current.length > 0) {
    words.push(current);
  }
  return words;
}

function wordsToCamel(words: Array<string>): string {
  let out: string = '';
  for (let i = 0; i < words.length; i++) {
    const w: string = words[i].toLowerCase();
    out = out + (i === 0 ? w : w.charAt(0).toUpperCase() + w.substring(1));
  }
  return out;
}

function wordsToPascal(words: Array<string>): string {
  let out: string = '';
  for (let i = 0; i < words.length; i++) {
    const w: string = words[i].toLowerCase();
    out = out + w.charAt(0).toUpperCase() + w.substring(1);
  }
  return out;
}

function wordsToJoined(words: Array<string>, sep: string, upper: boolean): string {
  const parts: Array<string> = [];
  for (let i = 0; i < words.length; i++) {
    parts.push(upper ? words[i].toLowerCase().toUpperCase() : words[i].toLowerCase());
  }
  return parts.join(sep);
}

/** 主入口：输入任意风格的标识符，输出六种风格 */
export function convertCase(input: string): CaseConvertResult {
  const text: string = input.trim();
  if (text.length === 0) {
    return new CaseConvertResult(false, new CaseFailure(CaseFailureCode.EMPTY_INPUT, []),
      '', '', '', '', '', '');
  }
  const words: Array<string> = splitNameWords(text);
  if (words.length === 0) {
    return new CaseConvertResult(false, new CaseFailure(CaseFailureCode.NO_WORDS, [text]),
      '', '', '', '', '', '');
  }
  return new CaseConvertResult(true, new CaseFailure(CaseFailureCode.NONE, []),
    wordsToCamel(words),
    wordsToPascal(words),
    wordsToJoined(words, '_', false),
    wordsToJoined(words, '_', true),
    wordsToJoined(words, '-', false),
    wordsToJoined(words, '.', false));
}
