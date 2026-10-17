/**
 * 正则测试工具的**纯逻辑层**。
 *
 * ## 为什么单独一个文件
 *
 * 正则测试的难点全在「不进 UI 也能判对错」的部分：表达式能不能编译、
 * 错误在第几个字符、零宽匹配会不会把循环卡死、高亮切段是否与匹配区间一致。
 * 这些必须能在 entry/src/test 里直接跑，所以本文件**不 import 任何**
 * ArkUI / @ohos.* 设备能力——一旦引入，单测连模块都加载不了。
 *
 * ## 一个必须自己处理的坑：零宽匹配
 *
 * 标准写法「循环调用 exec 直到返回 null」在遇到零宽匹配
 * （例如 a*、\b、^ 这些能匹配空串的表达式）时会**死循环**：
 * exec 命中空串后不会推进 lastIndex，下一次 exec 还在原地命中同一个空串。
 * 浏览器里 matchAll 内部帮我们做了推进，自己写循环就必须手动做，
 * 见 {@link nextSearchIndex}。这是本工具最容易翻车的地方。
 *
 * @module tools/regex-tester/RegexLogic
 */

import { NGFLocalizedText } from '../../core/ToolModel';

/** 简写构造器：把「中文 / English」写成一行 */
function l10n(zh: string, en: string): NGFLocalizedText {
  return new NGFLocalizedText(zh, en);
}

/** 匹配结果条数上限：防止 a* 这类表达式在长文本上产出几十万条把界面拖死 */
export const MAX_MATCHES: number = 2000;

/** 默认取多少条匹配 */
export const DEFAULT_MATCH_LIMIT: number = 500;

/** 高亮分段数上限：分段数约等于匹配数的两倍，长文本上不做限制会让渲染卡住 */
export const MAX_HIGHLIGHT_SEGMENTS: number = 800;

/** 单个标志（页面上的开关行与无障碍文本都要用） */
export enum RegexFlag {
  GLOBAL = 'global',
  IGNORE_CASE = 'ignore_case',
  MULTILINE = 'multiline',
  DOT_ALL = 'dot_all',
  UNICODE = 'unicode'
}

/** 正则标志开关。刻意做成不可变类：页面里每切换一个开关就得到一个新实例，UI 刷新不会漏。 */
export class RegexOptions {
  readonly global: boolean;
  readonly ignoreCase: boolean;
  readonly multiline: boolean;
  readonly dotAll: boolean;
  readonly unicode: boolean;

  constructor(global: boolean, ignoreCase: boolean, multiline: boolean, dotAll: boolean, unicode: boolean) {
    this.global = global;
    this.ignoreCase = ignoreCase;
    this.multiline = multiline;
    this.dotAll = dotAll;
    this.unicode = unicode;
  }

  /** 默认：只看第一个匹配之外的常用组合——全局开、其余关 */
  static defaults(): RegexOptions {
    return new RegexOptions(true, false, false, false, false);
  }

  /** 拼成 new RegExp 的第二个参数，顺序固定为 g i m s u（与文档里的写法一致） */
  toFlagString(): string {
    let flags: string = '';
    if (this.global) {
      flags = flags + 'g';
    }
    if (this.ignoreCase) {
      flags = flags + 'i';
    }
    if (this.multiline) {
      flags = flags + 'm';
    }
    if (this.dotAll) {
      flags = flags + 's';
    }
    if (this.unicode) {
      flags = flags + 'u';
    }
    return flags;
  }

  /**
   * 已开启的标志，给页面上的开关行做无障碍文本用。
   *
   * 返回**标志码数组**而不是拼好的句子：中文说「全局、忽略大小写」，
   * 英文说 "global, ignore case"，连接词与词本身都要换。空格时返回空数组。
   */
  describe(): Array<RegexFlag> {
    const on: Array<RegexFlag> = [];
    if (this.global) {
      on.push(RegexFlag.GLOBAL);
    }
    if (this.ignoreCase) {
      on.push(RegexFlag.IGNORE_CASE);
    }
    if (this.multiline) {
      on.push(RegexFlag.MULTILINE);
    }
    if (this.dotAll) {
      on.push(RegexFlag.DOT_ALL);
    }
    if (this.unicode) {
      on.push(RegexFlag.UNICODE);
    }
    return on;
  }

  withGlobal(value: boolean): RegexOptions {
    return new RegexOptions(value, this.ignoreCase, this.multiline, this.dotAll, this.unicode);
  }

  withIgnoreCase(value: boolean): RegexOptions {
    return new RegexOptions(this.global, value, this.multiline, this.dotAll, this.unicode);
  }

  withMultiline(value: boolean): RegexOptions {
    return new RegexOptions(this.global, this.ignoreCase, value, this.dotAll, this.unicode);
  }

  withDotAll(value: boolean): RegexOptions {
    return new RegexOptions(this.global, this.ignoreCase, this.multiline, value, this.unicode);
  }

  withUnicode(value: boolean): RegexOptions {
    return new RegexOptions(this.global, this.ignoreCase, this.multiline, this.dotAll, value);
  }

  /**
   * 从 g/i/m/s/u 字符串还原（草稿恢复时用）。
   *
   * 只看「有没有这个字母」而不是严格校验：草稿是本机存的历史数据，
   * 里面出现不认识的字母时忽略它即可，没必要因此判定草稿损坏。
   */
  static fromFlags(flags: string): RegexOptions {
    return new RegexOptions(
      flags.indexOf('g') >= 0,
      flags.indexOf('i') >= 0,
      flags.indexOf('m') >= 0,
      flags.indexOf('s') >= 0,
      flags.indexOf('u') >= 0
    );
  }
}

/**
 * 表达式的语法问题。
 *
 * position 是**从 0 开始**的字符下标（与 JS 内部口径一致），
 * 展示给用户时统一由 {@link RegexBuildResult} 里的中文提示加 1 换算成「第 N 个字符」。
 * 取不到位置时是 -1，此时提示里不带位置，而不是编一个假位置。
 */
/** 预检出来的问题种类（措辞在 UI 层） */
export enum RegexIssueKind {
  /** 反斜杠结尾，转义没写完 */
  TRAILING_BACKSLASH = 'trailing_backslash',
  /** 多了一个右括号 */
  UNMATCHED_CLOSE = 'unmatched_close',
  /** 量词前面没有可重复的内容 */
  NOTHING_TO_REPEAT = 'nothing_to_repeat',
  /** ? 前面没有可重复的内容 */
  NOTHING_TO_REPEAT_QUESTION = 'nothing_to_repeat_question',
  /** 中括号没有闭合 */
  UNTERMINATED_CLASS = 'unterminated_class',
  /** 括号没有闭合 */
  UNTERMINATED_GROUP = 'unterminated_group',
  /** 量词范围写反了（{m,n} 里 m > n） */
  RANGE_REVERSED = 'range_reversed'
}

export class RegexIssue {
  readonly kind: RegexIssueKind;
  /** 资源文案的占位符参数 */
  readonly args: Array<string>;
  readonly position: number;

  constructor(kind: RegexIssueKind, args: Array<string>, position: number) {
    this.kind = kind;
    this.args = args;
    this.position = position;
  }
}

/**
 * 引擎报错翻成人话后的**种类**。
 *
 * 为什么要有 UNKNOWN：引擎的措辞会随版本变化，对不上号时**不能把原文吞掉**——
 * 留着 rawMessage，开发者还能自己搜。UI 层据此决定是否补一句原始信息。
 */
export enum RegexErrorKind {
  /** 没有错误 */
  NONE = 'none',
  UNTERMINATED_GROUP = 'unterminated_group',
  UNMATCHED_CLOSE = 'unmatched_close',
  UNTERMINATED_CLASS = 'unterminated_class',
  NOTHING_TO_REPEAT = 'nothing_to_repeat',
  RANGE_OUT_OF_ORDER = 'range_out_of_order',
  INCOMPLETE_QUANTIFIER = 'incomplete_quantifier',
  INVALID_GROUP = 'invalid_group',
  INVALID_UNICODE_ESCAPE = 'invalid_unicode_escape',
  INVALID_ESCAPE = 'invalid_escape',
  INVALID_CHAR_CLASS = 'invalid_char_class',
  INVALID_PROPERTY = 'invalid_property',
  SYNTAX = 'syntax',
  PARSE_ERROR = 'parse_error',
  UNKNOWN = 'unknown'
}

/** 表达式编译结果。ok=false 时 regex 为 null，调用方必须先判 ok。 */
export class RegexBuildResult {
  readonly ok: boolean;
  readonly regex: RegExp | null;
  /** 失败原因的种类（措辞在 UI 层） */
  readonly errorKind: RegexErrorKind;
  /** 出错位置（从 0 开始）；-1 表示取不到位置，此时提示里不带位置，而不是编一个假位置 */
  readonly errorPosition: number;
  /** 引擎原文（中文提示对不上号时给开发者看的兜底信息，可能为空串） */
  readonly rawMessage: string;

  constructor(ok: boolean, regex: RegExp | null, errorKind: RegexErrorKind, errorPosition: number,
    rawMessage: string) {
    this.ok = ok;
    this.regex = regex;
    this.errorKind = errorKind;
    this.errorPosition = errorPosition;
    this.rawMessage = rawMessage;
  }
}

/** 单个捕获组 */
export class RegexCapture {
  /** 组序号，从 1 开始（0 是整个匹配，不在这里重复列） */
  readonly index: number;
  /** 命名捕获组的名字；不是命名组时为空串 */
  readonly name: string;
  /** 捕获到的文本；该组未参与匹配时为空串 */
  readonly value: string;

  constructor(index: number, name: string, value: string) {
    this.index = index;
    this.name = name;
    this.value = value;
  }
}

/** 一条匹配 */
export class RegexMatch {
  /** 序号，从 1 开始，供列表展示 */
  readonly ordinal: number;
  /** 起始下标（含） */
  readonly start: number;
  /** 结束下标（不含） */
  readonly end: number;
  readonly value: string;
  readonly captures: Array<RegexCapture>;

  constructor(ordinal: number, start: number, end: number, value: string, captures: Array<RegexCapture>) {
    this.ordinal = ordinal;
    this.start = start;
    this.end = end;
    this.value = value;
    this.captures = captures;
  }

  /** 这条匹配是否为零宽（长度 0）。零宽无法高亮，页面要单独提示。 */
  isZeroWidth(): boolean {
    return this.start === this.end;
  }
}

/** 高亮用的一段文本：要么是命中的部分，要么是没命中的部分 */
export class RegexSegment {
  readonly text: string;
  readonly matched: boolean;
  readonly start: number;

  constructor(text: string, matched: boolean, start: number) {
    this.text = text;
    this.matched = matched;
    this.start = start;
  }
}

/** 一次匹配执行的全部结果 */
export class RegexRunResult {
  readonly ok: boolean;
  readonly errorKind: RegexErrorKind;
  readonly errorPosition: number;
  readonly matches: Array<RegexMatch>;
  /** 是否因为达到上限而截断（页面必须明示，否则用户以为「只有这么多」） */
  readonly truncated: boolean;
  /** 被搜索文本的长度，供页面显示「N 条匹配 / M 字符」 */
  readonly textLength: number;

  constructor(ok: boolean, errorKind: RegexErrorKind, errorPosition: number,
              matches: Array<RegexMatch>, truncated: boolean, textLength: number) {
    this.ok = ok;
    this.errorKind = errorKind;
    this.errorPosition = errorPosition;
    this.matches = matches;
    this.truncated = truncated;
    this.textLength = textLength;
  }

  /** 零宽匹配条数：这类匹配无法高亮，页面据此给一句说明 */
  zeroWidthCount(): number {
    let count: number = 0;
    for (let i: number = 0; i < this.matches.length; i++) {
      if (this.matches[i].isZeroWidth()) {
        count++;
      }
    }
    return count;
  }
}

/** 常用预设 */
export class RegexPreset {
  /** 预设名（双语数据，按 locale 取） */
  readonly name: NGFLocalizedText;
  readonly pattern: string;
  /** 一句话说明（双语数据） */
  readonly hint: NGFLocalizedText;
  /** 用这个预设时应同时应用的标志（例如「空白行」必须开多行） */
  readonly options: RegexOptions;

  constructor(name: NGFLocalizedText, pattern: string, hint: NGFLocalizedText,
    options: RegexOptions) {
    this.name = name;
    this.pattern = pattern;
    this.hint = hint;
    this.options = options;
  }
}

/** 速查表条目 */
export class RegexCheatSheetItem {
  readonly token: string;
  /** 含义（双语数据） */
  readonly meaning: NGFLocalizedText;

  constructor(token: string, meaning: NGFLocalizedText) {
    this.token = token;
    this.meaning = meaning;
  }
}

/** 数字字符判断（不用正则，保持零依赖、零分配） */
function isDigit(ch: string): boolean {
  return ch >= '0' && ch <= '9';
}

/**
 * 把引擎报错翻成人话。
 *
 * 引擎原文是英文且措辞会随版本变化，直接展示给中文用户没有意义；
 * 但对不上号时也不能把原文吞掉——留着它开发者还能自己搜。
 */
export function friendlyRegexError(rawMessage: string): RegexErrorKind {
  const raw: string = rawMessage;
  if (raw.indexOf('Unterminated group') >= 0) {
    return RegexErrorKind.UNTERMINATED_GROUP;
  }
  if (raw.indexOf('Unmatched') >= 0 && raw.indexOf(')') >= 0) {
    return RegexErrorKind.UNMATCHED_CLOSE;
  }
  if (raw.indexOf('Unterminated character class') >= 0) {
    return RegexErrorKind.UNTERMINATED_CLASS;
  }
  if (raw.indexOf('Nothing to repeat') >= 0) {
    return RegexErrorKind.NOTHING_TO_REPEAT;
  }
  if (raw.indexOf('numbers out of order') >= 0) {
    return RegexErrorKind.RANGE_OUT_OF_ORDER;
  }
  if (raw.indexOf('Lone quantifier brackets') >= 0) {
    return RegexErrorKind.INCOMPLETE_QUANTIFIER;
  }
  if (raw.indexOf('Invalid group') >= 0) {
    return RegexErrorKind.INVALID_GROUP;
  }
  if (raw.indexOf('Invalid Unicode escape') >= 0) {
    return RegexErrorKind.INVALID_UNICODE_ESCAPE;
  }
  if (raw.indexOf('Invalid escape') >= 0) {
    return RegexErrorKind.INVALID_ESCAPE;
  }
  if (raw.indexOf('Invalid character class') >= 0) {
    return RegexErrorKind.INVALID_CHAR_CLASS;
  }
  if (raw.indexOf('Invalid property name') >= 0) {
    return RegexErrorKind.INVALID_PROPERTY;
  }
  if (raw.indexOf('Invalid regular expression') >= 0) {
    return RegexErrorKind.SYNTAX;
  }
  // 兜底分两种，别把线索吞掉：
  // 引擎给了原文但对不上任何已知措辞 → UNKNOWN，UI 会把原文一起显示出来（开发者能自己搜）；
  // 连原文都没有 → PARSE_ERROR，只能说「无法解析」。
  if (raw.length === 0) {
    return RegexErrorKind.PARSE_ERROR;
  }
  return RegexErrorKind.UNKNOWN;
}

/**
 * 括号/量词安全检查，用来给「引擎没说清错在第几个字符」的情况补位置。
 *
 * 为什么不只依赖引擎报错：各引擎的错误信息里**不保证**带位置
 * （V8 就不带），只显示「语法错误」对用户毫无帮助。
 * 这里用一次线性扫描找出最常见的几类结构错误并给出准确下标；
 * 它不追求覆盖全部语法（那是引擎的活），只在引擎已经报错后帮忙定位。
 */
export function analyzePattern(pattern: string): RegexIssue | null {
  const openStack: Array<number> = [];
  let inClass: boolean = false;
  let classStart: number = -1;
  let i: number = 0;
  while (i < pattern.length) {
    const ch: string = pattern.charAt(i);
    if (ch === '\\') {
      if (i === pattern.length - 1) {
        return new RegexIssue(RegexIssueKind.TRAILING_BACKSLASH, [], i);
      }
      i = i + 2;
      continue;
    }
    if (inClass) {
      if (ch === ']') {
        inClass = false;
      }
      i++;
      continue;
    }
    if (ch === '[') {
      inClass = true;
      classStart = i;
      i++;
      continue;
    }
    if (ch === '(') {
      openStack.push(i);
      i++;
      continue;
    }
    if (ch === ')') {
      if (openStack.length === 0) {
        return new RegexIssue(RegexIssueKind.UNMATCHED_CLOSE, [], i);
      }
      openStack.pop();
      i++;
      continue;
    }
    if (ch === '*' || ch === '+') {
      const prev: string = i === 0 ? '' : pattern.charAt(i - 1);
      if (i === 0 || prev === '(' || prev === '|') {
        return new RegexIssue(RegexIssueKind.NOTHING_TO_REPEAT, [], i);
      }
      i++;
      continue;
    }
    if (ch === '?') {
      // (? 是分组前缀（(?: (?= (?! (?<name>），不是量词——把它当成量词
      // 会把 (?:...) 这种完全合法的写法误判成语法错误（这是一个真实踩过的坑）。
      const prev: string = i === 0 ? '' : pattern.charAt(i - 1);
      if (i === 0 || prev === '|') {
        return new RegexIssue(RegexIssueKind.NOTHING_TO_REPEAT_QUESTION, [], i);
      }
      i++;
      continue;
    }
    if (ch === '{') {
      const close: number = pattern.indexOf('}', i);
      if (close > i && looksLikeQuantifier(pattern, i, close)) {
        const range: RegexIssue | null = checkQuantifierRange(pattern, i, close);
        if (range !== null) {
          return range;
        }
        i = close + 1;
        continue;
      }
      i++;
      continue;
    }
    i++;
  }
  if (inClass) {
    return new RegexIssue(RegexIssueKind.UNTERMINATED_CLASS, [], classStart);
  }
  if (openStack.length > 0) {
    const lastOpen: number = openStack[openStack.length - 1];
    return new RegexIssue(RegexIssueKind.UNTERMINATED_GROUP, [], lastOpen);
  }
  return null;
}

/** { 到 } 之间是不是合法的量词内容（纯数字，或 数字, 或 数字,数字） */
function looksLikeQuantifier(pattern: string, openIndex: number, closeIndex: number): boolean {
  const body: string = pattern.substring(openIndex + 1, closeIndex);
  if (body.length === 0) {
    return false;
  }
  const commaIndex: number = body.indexOf(',');
  if (commaIndex < 0) {
    return isAllDigits(body);
  }
  const left: string = body.substring(0, commaIndex);
  const right: string = body.substring(commaIndex + 1);
  if (!isAllDigits(left)) {
    return false;
  }
  if (right.length === 0) {
    return true;
  }
  return isAllDigits(right);
}

function isAllDigits(text: string): boolean {
  if (text.length === 0) {
    return false;
  }
  for (let i: number = 0; i < text.length; i++) {
    if (!isDigit(text.charAt(i))) {
      return false;
    }
  }
  return true;
}

/** {m,n} 里 m > n 属于结构性错误，引擎会报错但一般不给位置，这里补上 */
function checkQuantifierRange(pattern: string, openIndex: number, closeIndex: number): RegexIssue | null {
  const body: string = pattern.substring(openIndex + 1, closeIndex);
  const commaIndex: number = body.indexOf(',');
  if (commaIndex < 0 || commaIndex === body.length - 1) {
    return null;
  }
  const left: string = body.substring(0, commaIndex);
  const right: string = body.substring(commaIndex + 1);
  if (!isAllDigits(left) || !isAllDigits(right)) {
    return null;
  }
  const min: number = Number.parseInt(left, 10);
  const max: number = Number.parseInt(right, 10);
  if (min > max) {
    return new RegexIssue(RegexIssueKind.RANGE_REVERSED, [left, right], openIndex);
  }
  return null;
}

/**
 * 从引擎报错里抠出「位置」。
 *
 * 有些引擎会给出 at position N，V8 不给——两种都要能处理，
 * 抠不到就交给 {@link analyzePattern} 兜底。
 */
export function extractErrorPosition(rawMessage: string): number {
  const marker: string = 'at position ';
  const markerIndex: number = rawMessage.indexOf(marker);
  if (markerIndex < 0) {
    return -1;
  }
  let cursor: number = markerIndex + marker.length;
  let digits: string = '';
  while (cursor < rawMessage.length && isDigit(rawMessage.charAt(cursor))) {
    digits = digits + rawMessage.charAt(cursor);
    cursor++;
  }
  if (digits.length === 0) {
    return -1;
  }
  return Number.parseInt(digits, 10);
}

/**
 * 编译正则表达式。
 *
 * 返回**结果对象**而不是抛异常：调用方（页面）需要在每次输入变化时调用它，
 * 异常控制流会让「非法表达式」这条正常路径写得像错误处理。
 */
export function buildRegex(pattern: string, options: RegexOptions): RegexBuildResult {
  const flags: string = options.toFlagString();
  try {
    const compiled: RegExp = new RegExp(pattern, flags);
    return new RegexBuildResult(true, compiled, RegexErrorKind.NONE, -1, '');
  } catch (error) {
    // 与仓库其它地方一致：catch 变量不写类型标注，用 as 收窄后取 message
    // （new RegExp 抛的一定是 SyntaxError，message 必定是字符串）。
    const failure: Error = error as Error;
    const raw: string = failure.message;
    const friendly: RegexErrorKind = friendlyRegexError(raw);
    let position: number = extractErrorPosition(raw);
    if (position < 0) {
      const issue: RegexIssue | null = analyzePattern(pattern);
      if (issue !== null) {
        position = issue.position;
      }
    }
    let errorKind: RegexErrorKind = friendly;
    if (position >= 0) {
      // 位置只带出去，不拼进句子——中文写「第 3 个字符附近」，英文写 "near character 3"
    }
    return new RegexBuildResult(false, null, errorKind, position, raw);
  }
}

/**
 * 零宽匹配后把搜索位置往前推一格。
 *
 * 这是防死循环的关键一步。为什么要跳过整个代理对：在 u 标志下
 * 把 lastIndex 停在一个代理对的中间会让后续匹配行为变得难以解释，
 * 直接跳过一对字符更符合用户直觉。
 */
export function nextSearchIndex(text: string, index: number): number {
  if (index >= text.length) {
    return index + 1;
  }
  const code: number = text.charCodeAt(index);
  const isHighSurrogate: boolean = code >= 0xD800 && code <= 0xDBFF;
  if (isHighSurrogate && index + 1 < text.length) {
    const next: number = text.charCodeAt(index + 1);
    if (next >= 0xDC00 && next <= 0xDFFF) {
      return index + 2;
    }
  }
  return index + 1;
}

/**
 * 扫出**每个捕获组**的名字，下标与组号严格对应（下标 0 = 第 1 组）。
 *
 * ## 为什么必须逐组占位，而不是只收集「有名字的那些」
 *
 * 曾经的写法是「只把命名组推进数组」，于是 (a)(?<b>c) 得到的数组是 ['b']，
 * 再按「组号 - 1」去取就把第 1 组（无名的 a）读成了名字 'b'——展示出来的
 * 分组名与内容完全对不上。捕获组序号是**位置决定**的：普通组也占号，
 * 因此数组里必须有无名组的空串占位。
 *
 * 不直接读 match.groups 的原因：那是「按名字取属性」的动态访问，
 * 规范禁止 obj[dynamicKey]。自己扫一遍既绕开动态访问，
 * 也让展示不依赖引擎实现。
 * 非捕获组 (?:、前瞻 (?= (?!、后顾 (?<= (?<! 都不占组号，必须跳过。
 */
export function captureGroupNames(pattern: string): Array<string> {
  const names: Array<string> = [];
  let i: number = 0;
  while (i < pattern.length) {
    const ch: string = pattern.charAt(i);
    if (ch === '\\') {
      i = i + 2;
      continue;
    }
    if (ch === '[') {
      const close: number = findClassEnd(pattern, i);
      i = close < 0 ? pattern.length : close + 1;
      continue;
    }
    if (ch === '(') {
      if (pattern.charAt(i + 1) !== '?') {
        // 普通捕获组：占号但没有名字
        names.push('');
        i++;
        continue;
      }
      if (pattern.charAt(i + 2) === '<') {
        const afterMarker: string = pattern.charAt(i + 3);
        const isLookbehind: boolean = afterMarker === '=' || afterMarker === '!';
        if (!isLookbehind) {
          const closeIndex: number = pattern.indexOf('>', i + 3);
          if (closeIndex > 0) {
            names.push(pattern.substring(i + 3, closeIndex));
            i = closeIndex + 1;
            continue;
          }
        }
      }
      // (?:、(?=、(?!、(?<=、(?<!：不占组号
      i++;
      continue;
    }
    i++;
  }
  return names;
}

/** 找到字符组 [ 的收尾位置；找不到返回 -1 */
function findClassEnd(pattern: string, openIndex: number): number {
  let i: number = openIndex + 1;
  while (i < pattern.length) {
    const ch: string = pattern.charAt(i);
    if (ch === '\\') {
      i = i + 2;
      continue;
    }
    if (ch === ']') {
      return i;
    }
    i++;
  }
  return -1;
}

/** 把上限夹到合法区间：<=0 用默认值，超过 MAX_MATCHES 用 MAX_MATCHES */
export function clampMatchLimit(limit: number): number {
  if (limit <= 0) {
    return DEFAULT_MATCH_LIMIT;
  }
  if (limit > MAX_MATCHES) {
    return MAX_MATCHES;
  }
  return Math.floor(limit);
}

/**
 * 编译失败就返回 null 的小包装。
 *
 * 单独抽出来是为了让「可能抛异常的调用」与「后续逻辑」分开：
 * 在 try 里声明变量、在 try 外使用，类型检查器并不保证它一定被赋值过。
 */
function compileQuietly(pattern: string, flags: string): RegExp | null {
  try {
    return new RegExp(pattern, flags);
  } catch (error) {
    return null;
  }
}

/**
 * 执行匹配。
 *
 * 迭代版正则**始终带 g**：不带 g 的 exec 永远返回第一个匹配，
 * 循环就没有意义；用户关掉「全局」时我们只在最后取第一条。
 * 这样「条数上限 / 零宽推进 / 截断标记」三条逻辑只有一份实现。
 */
export function runRegex(pattern: string, text: string, options: RegexOptions, limit: number): RegexRunResult {
  const build: RegexBuildResult = buildRegex(pattern, options);
  if (!build.ok) {
    return new RegexRunResult(false, build.errorKind, build.errorPosition, [], false, text.length);
  }
  const maxCount: number = clampMatchLimit(limit);
  const baseFlags: string = options.toFlagString();
  const iterateFlags: string = baseFlags.indexOf('g') >= 0 ? baseFlags : baseFlags + 'g';
  const scannerOrNull: RegExp | null = compileQuietly(pattern, iterateFlags);
  if (scannerOrNull === null) {
    // 兜底：buildRegex 刚刚成功、这里不该失败，真失败了也只给一条错误而不是抛出去。
    return new RegexRunResult(false, RegexErrorKind.SYNTAX, -1, [], false, text.length);
  }
  const scanner: RegExp = scannerOrNull;
  // 组号 -> 名字（无名组用空串占位，下标 0 对应第 1 组）
  const names: Array<string> = captureGroupNames(pattern);
  const matches: Array<RegexMatch> = [];
  let truncated: boolean = false;
  // 迭代次数上限：零宽推进已经保证不会无限循环，这里再加一道保险，
  // 万一引擎出现意料之外的行为也只是少给几条结果，而不是把页面挂死。
  const maxIterations: number = maxCount * 4 + 64;
  let iterations: number = 0;
  scanner.lastIndex = 0;
  let current: RegExpExecArray | null = scanner.exec(text);
  while (current !== null) {
    iterations++;
    if (iterations > maxIterations) {
      truncated = true;
      break;
    }
    if (matches.length >= maxCount) {
      truncated = true;
      break;
    }
    const value: string = current[0];
    const captures: Array<RegexCapture> = [];
    const groups: Array<string | undefined> = current as Array<string | undefined>;
    for (let g: number = 1; g < groups.length; g++) {
      const captured: string | undefined = groups[g];
      const groupText: string = captured === undefined ? '' : captured;
      const groupName: string = g - 1 < names.length ? names[g - 1] : '';
      captures.push(new RegexCapture(g, groupName, groupText));
    }
    matches.push(new RegexMatch(matches.length + 1, current.index, current.index + value.length, value, captures));
    if (!options.global) {
      break;
    }
    if (value.length === 0) {
      scanner.lastIndex = nextSearchIndex(text, scanner.lastIndex);
    }
    current = scanner.exec(text);
  }
  return new RegexRunResult(true, RegexErrorKind.NONE, -1, matches, truncated, text.length);
}

/**
 * 把文本切成「命中 / 未命中」交替的段，供页面渲染高亮。
 *
 * 零宽匹配会被跳过：它没有任何字符可染色，硬塞一段空文本
 * 只会在界面上留下看不见的空节点。这类匹配由匹配列表负责展示。
 *
 * ## 超限时为什么保留**尾部**而不是头部
 *
 * maxSegments 是给渲染用的上限。超限时若保留头部，用户看到的是文本最开头
 * 那几处命中——而实际被粘进来的长文本（日志、抓包）里，用户关心的是**最后**
 * 发生了什么。这与 ToolStateStore.clampDraft 对超长草稿「保留尾部」的口径一致：
 * 全应用统一「越靠后越可能是用户正在看的东西」。
 * 保留尾部的前提是先切出全部段再取末 N 段，所以这里分两步做。
 */
export function buildSegments(text: string, matches: Array<RegexMatch>, maxSegments: number): Array<RegexSegment> {
  const all: Array<RegexSegment> = splitAllSegments(text, matches);
  if (maxSegments <= 0 || all.length <= maxSegments) {
    return all;
  }
  const tail: Array<RegexSegment> = [];
  for (let i: number = all.length - maxSegments; i < all.length; i++) {
    tail.push(all[i]);
  }
  return tail;
}

/** 切出全部段（不设上限）；段与段首尾相接，拼起来就是原文 */
function splitAllSegments(text: string, matches: Array<RegexMatch>): Array<RegexSegment> {
  const segments: Array<RegexSegment> = [];
  let cursor: number = 0;
  for (let i: number = 0; i < matches.length; i++) {
    const match: RegexMatch = matches[i];
    if (match.end <= match.start) {
      continue;
    }
    if (match.start < cursor) {
      // 理论上不会发生（正则匹配不重叠）；真出现了也不能让文本被重复拼接。
      continue;
    }
    if (match.start > cursor) {
      segments.push(new RegexSegment(text.substring(cursor, match.start), false, cursor));
    }
    segments.push(new RegexSegment(text.substring(match.start, match.end), true, match.start));
    cursor = match.end;
  }
  if (cursor < text.length) {
    segments.push(new RegexSegment(text.substring(cursor), false, cursor));
  }
  return segments;
}

/**
 * 一次运行的摘要的**结构**（措辞在 UI 层）。
 *
 * 原先这里直接拼中文（'匹配到 3 处（已达上限 20 条…）'）。改成结构之后，
 * 「几处」「几条」「几个字符」这些数字原样带出去——中英语序与量词都不同。
 */
export class RegexSummary {
  readonly ok: boolean;
  /** 匹配数为 0 */
  readonly empty: boolean;
  readonly matchCount: number;
  readonly truncated: boolean;
  readonly limit: number;
  readonly zeroWidth: number;
  readonly textLength: number;

  constructor(ok: boolean, empty: boolean, matchCount: number, truncated: boolean,
    limit: number, zeroWidth: number, textLength: number) {
    this.ok = ok;
    this.empty = empty;
    this.matchCount = matchCount;
    this.truncated = truncated;
    this.limit = limit;
    this.zeroWidth = zeroWidth;
    this.textLength = textLength;
  }
}

/** 一条结果摘要，页面顶部显示 */
export function summarizeRun(result: RegexRunResult): RegexSummary {
  if (!result.ok) {
    return new RegexSummary(false, false, 0, false, MAX_MATCHES, 0, result.textLength);
  }
  return new RegexSummary(true, result.matches.length === 0, result.matches.length,
    result.truncated, MAX_MATCHES, result.zeroWidthCount(), result.textLength);
}

/** 把换行/制表符转成可见转义，保证报告里「一条匹配 = 一行」 */
function escapeReportLine(text: string): string {
  return text.split('\r').join('\\r').split('\n').join('\\n').split('\t').join('\\t');
}

/**
 * 生成可直接复制走的文本报告。
 *
 * 为什么报告也放在纯逻辑里：它是用户会粘到工单、聊天窗口里的东西，
 * 格式一旦错了（例如匹配值里的换行把一行拆成两行）就是可感知的缺陷，
 * 而这种缺陷在真机上肉眼很难稳定复现，放在单测里才守得住。
 *
 * **措辞由调用方注入**（summaryText / errorText）：格式留在这里守住，
 * 句子本身归 UI 层——中英两套句子拼进同一份格式里，格式才只有一份。
 */
export function buildMatchReport(result: RegexRunResult, summaryText: string,
  errorText: string): string {
  if (!result.ok) {
    return errorText;
  }
  const lines: Array<string> = [];
  lines.push(summaryText);
  for (let i: number = 0; i < result.matches.length; i++) {
    const match: RegexMatch = result.matches[i];
    let line: string = '#' + String(match.ordinal) + ' [' + String(match.start) + ',' + String(match.end) + ') '
      + escapeReportLine(match.value);
    for (let g: number = 0; g < match.captures.length; g++) {
      const capture: RegexCapture = match.captures[g];
      const name: string = capture.name.length > 0 ? capture.name : String(capture.index);
      line = line + '  $' + name + '=' + escapeReportLine(capture.value);
    }
    lines.push(line);
  }
  return lines.join('\n');
}

/** 常用预设：全部用字符串拼接构造，避免顶层对象字面量的类型标注问题 */
export function regexPresets(): Array<RegexPreset> {
  const list: Array<RegexPreset> = [];
  const globalOnly: RegexOptions = RegexOptions.defaults();
  const globalMultiline: RegexOptions = RegexOptions.defaults().withMultiline(true);
  const globalIgnoreCase: RegexOptions = RegexOptions.defaults().withIgnoreCase(true);
  list.push(new RegexPreset(l10n('邮箱地址（简化）', 'Email address (simplified)'), '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}',
    l10n('不校验域名是否真实存在，也不覆盖全部 RFC 5322 合法写法',
    'Does not check that the domain really exists, and does not cover every valid RFC 5322 form'), globalOnly));
  list.push(new RegexPreset(l10n('IPv4 地址', 'IPv4 address'), '\\b(?:(?:25[0-5]|2[0-4]\\d|1?\\d?\\d)\\.){3}(?:25[0-5]|2[0-4]\\d|1?\\d?\\d)\\b',
    l10n('只做格式校验，255.255.255.255 这类广播地址也会通过',
    'Format check only — broadcast addresses such as 255.255.255.255 pass too'), globalOnly));
  list.push(new RegexPreset(l10n('日期 YYYY-MM-DD', 'Date YYYY-MM-DD'), '\\b\\d{4}-\\d{2}-\\d{2}\\b',
    l10n('只校验形状，2024-13-45 也会通过；要校验真实性请用日期计算工具',
    'Shape only: 2024-13-45 passes too. Use the date calculator to check real dates'), globalOnly));
  list.push(new RegexPreset(l10n('时间 HH:mm:ss', 'Time HH:mm:ss'), '\\b\\d{2}:\\d{2}:\\d{2}\\b',
    l10n('同样是形状校验，不做 0-23/0-59 范围判断',
      'Also shape only — no 0-23 / 0-59 range check'), globalOnly));
  list.push(new RegexPreset(l10n('网址 http/https', 'URL http/https'), 'https?://[^\\s\"\'<>]+', l10n('遇到中文标点或右括号会提前停下，不做 URL 语法解析',
    'Stops early at CJK punctuation or a closing bracket; no URL syntax parsing'), globalOnly));
  list.push(new RegexPreset(l10n('中国大陆手机号', 'Mainland China mobile number'), '\\b1[3-9]\\d{9}\\b', l10n('只按号段前缀判断，不判断号码是否在用',
    'Matches the number prefix only; does not check whether the number is in use'), globalOnly));
  list.push(new RegexPreset(l10n('十六进制颜色', 'Hex colour'), '#(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})\\b', l10n('匹配 #RGB 与 #RRGGBB 两种写法', 'Matches both #RGB and #RRGGBB'), globalOnly));
  list.push(new RegexPreset(l10n('中文字符', 'Chinese characters'), '[\\u4e00-\\u9fa5]+', l10n('只覆盖基本汉字区，不含扩展区与生僻字',
    'Covers the basic CJK block only — not the extensions or rare characters'), globalOnly));
  list.push(new RegexPreset(l10n('空白行', 'Blank line'), '^[ \\t]*$', l10n('需要「多行」标志，否则 ^ $ 只认整段文本的首尾',
    'Needs the multiline flag, otherwise ^ and $ only match the whole text'), globalMultiline));
  list.push(new RegexPreset(l10n('重复单词（反向引用）', 'Repeated word (backreference)'), '\\b(\\w+)\\s+\\1\\b', l10n('演示反向引用 \\1：找「the the」这类相邻重复词',
    'Shows backreference \\1: finds adjacent repeats such as "the the"'), globalIgnoreCase));
  return list;
}

/** 速查表：语法太碎，放在纯逻辑里而不是页面里，方便以后做搜索 */
export function regexCheatSheet(): Array<RegexCheatSheetItem> {
  const list: Array<RegexCheatSheetItem> = [];
  list.push(new RegexCheatSheetItem('.', l10n('任意字符（默认不含换行；开 s 标志后含换行）', 'Any character (not newline by default; with the s flag, newlines too)')));
  list.push(new RegexCheatSheetItem('\\d', l10n('数字 0-9；\\D 反之', 'A digit 0-9; \\D is the opposite')));
  list.push(new RegexCheatSheetItem('\\w', l10n('字母、数字、下划线；\\W 反之', 'Letter, digit or underscore; \\W is the opposite')));
  list.push(new RegexCheatSheetItem('\\s', l10n('空白字符（空格、制表符、换行）；\\S 反之', 'Whitespace (space, tab, newline); \\S is the opposite')));
  list.push(new RegexCheatSheetItem('\\b', l10n('单词边界（零宽，只定位不消耗字符）', 'Word boundary (zero-width: it anchors without consuming)')));
  list.push(new RegexCheatSheetItem('^', l10n('行首（多行标志下是每行行首）', 'Start of line (with the multiline flag, of every line)')));
  list.push(new RegexCheatSheetItem('$', l10n('行尾（多行标志下是每行行尾）', 'End of line (with the multiline flag, of every line)')));
  list.push(new RegexCheatSheetItem('*', l10n('前面内容重复 0 次或多次', 'The preceding item, zero or more times')));
  list.push(new RegexCheatSheetItem('+', l10n('前面内容重复 1 次或多次', 'The preceding item, one or more times')));
  list.push(new RegexCheatSheetItem('?', l10n('前面内容出现 0 次或 1 次', 'The preceding item, zero or one time')));
  list.push(new RegexCheatSheetItem('{n} / {n,} / {n,m}', l10n('重复 n 次 / 至少 n 次 / n 到 m 次', 'Exactly n times / at least n times / between n and m times')));
  list.push(new RegexCheatSheetItem('*? +? ??', l10n('量词后加 ? 变成懒惰匹配（尽量少匹配）', 'Adding ? after a quantifier makes it lazy (match as little as possible)')));
  list.push(new RegexCheatSheetItem('[abc]', l10n('字符组：a、b、c 中任意一个', 'Character class: any one of a, b or c')));
  list.push(new RegexCheatSheetItem('[^abc]', l10n('排除型字符组：除 a、b、c 之外的任意字符', 'Negated class: any character except a, b or c')));
  list.push(new RegexCheatSheetItem('[a-z]', l10n('范围：a 到 z', 'A range: a through z')));
  list.push(new RegexCheatSheetItem('(abc)', l10n('捕获组，结果里按组号列出', 'Capturing group — listed by group number in the results')));
  list.push(new RegexCheatSheetItem('(?:abc)', l10n('非捕获组：只分组不占用组号', 'Non-capturing group: groups without using a group number')));
  list.push(new RegexCheatSheetItem('(?<name>abc)', l10n('命名捕获组，本工具按序号展示它的内容', 'Named capturing group; this tool shows its content by number')));
  list.push(new RegexCheatSheetItem('(?=abc)', l10n('正向先行断言：后面必须是 abc（零宽）', 'Positive lookahead: what follows must be abc (zero-width)')));
  list.push(new RegexCheatSheetItem('(?!abc)', l10n('负向先行断言：后面不能是 abc（零宽）', 'Negative lookahead: what follows must not be abc (zero-width)')));
  list.push(new RegexCheatSheetItem('\\1', l10n('反向引用第 1 个捕获组的内容', 'Backreference to what the first capturing group matched')));
  list.push(new RegexCheatSheetItem('a|b', l10n('或：匹配 a 或 b', 'Alternation: match a or b')));
  list.push(new RegexCheatSheetItem('\\u4e2d', l10n('按 Unicode 码点匹配（这里是「中」）', 'Match by Unicode code point (for example U+4E2D)')));
  return list;
}

/**
 * 输入草稿的持久化形状。
 *
 * 为什么正则工具要单独一个结构：本工具有**两个**都要紧的输入——
 * 表达式和测试文本。只存其中一个，用户下次打开就会发现另一半没了，
 * 比两个都不存更让人困惑。
 */
export class RegexDraft {
  pattern: string = '';
  subject: string = '';
  /** 标志位的字母形式（g/i/m/s/u），复用 {@link RegexOptions.fromFlags} 还原 */
  flags: string = '';
}

/**
 * 草稿里单个字段的字符上限。
 *
 * 为什么必须在这里裁：ToolStateStore 对整份草稿有 100000 字符的硬上限，
 * 超出时它保留**尾部**——而它并不知道那是一段 JSON。被截尾的 JSON 解析必然失败，
 * 用户看到的就是「草稿没存上」，比不存更糟。所以序列化前先把各字段裁到安全长度，
 * 保证整份 JSON 一定远小于存储上限（两个字段之和 42000，余量充足）。
 */
export const REGEX_DRAFT_PATTERN_MAX: number = 2000;
export const REGEX_DRAFT_SUBJECT_MAX: number = 40000;

/** 保留尾部的截断：用户最近在改的是尾部，比开头更有价值 */
export function keepTail(text: string, max: number): string {
  if (max <= 0) {
    return '';
  }
  if (text.length <= max) {
    return text;
  }
  return text.substring(text.length - max);
}

/** 序列化草稿。字段少、结构固定，直接用 JSON，不必自造格式。 */
export function serializeRegexDraft(draft: RegexDraft): string {
  const safe: RegexDraft = new RegexDraft();
  safe.pattern = keepTail(draft.pattern, REGEX_DRAFT_PATTERN_MAX);
  safe.subject = keepTail(draft.subject, REGEX_DRAFT_SUBJECT_MAX);
  safe.flags = draft.flags;
  return JSON.stringify(safe);
}

/**
 * 反序列化草稿。
 *
 * 任何损坏输入都退化为空草稿而不抛异常——与 ToolStateModel 的口径一致：
 * 草稿只是「方便」，为了一份坏掉的方便数据让工具页打不开，是错误的取舍。
 */
export function parseRegexDraft(raw: string): RegexDraft {
  const draft: RegexDraft = new RegexDraft();
  const text: string = raw.trim();
  if (text.length === 0) {
    return draft;
  }
  try {
    const parsed: RegexDraft = JSON.parse(text) as RegexDraft;
    draft.pattern = parsed.pattern ? parsed.pattern : '';
    draft.subject = parsed.subject ? parsed.subject : '';
    draft.flags = parsed.flags ? parsed.flags : '';
    return draft;
  } catch (error) {
    return draft;
  }
}