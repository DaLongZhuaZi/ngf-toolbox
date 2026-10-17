/**
 * JWT 载荷/头部用的最小 JSON 解析与美化（纯逻辑）。
 *
 * ## 为什么要自己写一个 JSON 解析器
 *
 * JWT 工具需要三件 JSON 相关的事，而 ArkTS 里没有一件能直接用现成 API 干净地做到：
 *
 * 1. **定位错误**：`JSON.parse` 抛出的错误信息里没有行列号，用户粘错一个逗号
 *    只能自己数；本工具要按「第 X 行第 Y 列」指出来。
 * 2. **保留数值原文**：JWT 里的 `exp`/`iat` 是时间戳，而 JSON 的数值一旦转成
 *    `number` 就可能丢精度（超过 2^53 的整数），工具应当原样呈现。
 * 3. **分层**：纯逻辑不能 import 任何设备能力，而带类型的 `JSON.parse` 结果在
 *    ArkTS 严格模式下只能靠类型断言硬掰，正是最容易被评审挑出来的写法。
 *
 * 解析器只支持标准 JSON（RFC 8259），不认注释与尾逗号——JWT 载荷本来就只能是标准 JSON，
 * 放宽语法只会让「明明不是合法 JWT」的输入被勉强解析出来。
 *
 * @module tools/jwt-decoder/JwtJson
 */

/** JSON 值的种类 */
export enum NGFJsonKind {
  OBJECT = 'object',
  ARRAY = 'array',
  STRING = 'string',
  NUMBER = 'number',
  BOOLEAN = 'boolean',
  NULL = 'null'
}

/** 对象里的一个成员（键 + 值）。用类而不是 Map：JSON 允许重复键，顺序也要保留 */
export class NGFJsonMember {
  readonly key: string;
  readonly value: NGFJsonNode;

  constructor(key: string, value: NGFJsonNode) {
    this.key = key;
    this.value = value;
  }
}

/** 解析后的一棵 JSON 值树 */
export class NGFJsonNode {
  readonly kind: NGFJsonKind;
  /** 原始文本：数值保留原样（不转 number），字符串保留**未转义**的原文 */
  readonly text: string;
  /** 字符串转义解码后的内容（kind 为 STRING 时有意义） */
  readonly stringValue: string;
  /** 布尔值（kind 为 BOOLEAN 时有意义） */
  readonly booleanValue: boolean;
  /** 对象成员（kind 为 OBJECT 时有意义） */
  readonly members: NGFJsonMember[];
  /** 数组元素（kind 为 ARRAY 时有意义） */
  readonly items: NGFJsonNode[];

  constructor(kind: NGFJsonKind, text: string, stringValue: string, booleanValue: boolean,
    members: NGFJsonMember[], items: NGFJsonNode[]) {
    this.kind = kind;
    this.text = text;
    this.stringValue = stringValue;
    this.booleanValue = booleanValue;
    this.members = members;
    this.items = items;
  }

  /** 空对象/空数组/标量的快捷构造 */
  static scalar(kind: NGFJsonKind, text: string, stringValue: string, booleanValue: boolean): NGFJsonNode {
    const noMembers: NGFJsonMember[] = [];
    const noItems: NGFJsonNode[] = [];
    return new NGFJsonNode(kind, text, stringValue, booleanValue, noMembers, noItems);
  }
}

/** 一维位置（1 基），用于把错误指到具体字符 */
export class NGFJsonPosition {
  readonly line: number;
  readonly column: number;

  constructor(line: number, column: number) {
    this.line = line;
    this.column = column;
  }
}

/** 解析结果：失败时带位置与原因，成功时带树 */
export class NGFJsonParseResult {
  readonly ok: boolean;
  readonly root: NGFJsonNode | null;
  /** 失败原因；成功时为 NONE（**永不为 null**） */
  readonly failure: NGFJsonFailure;
  readonly args: Array<string>;
  readonly position: NGFJsonPosition;

  constructor(ok: boolean, root: NGFJsonNode | null, failure: NGFJsonFailure,
    args: Array<string>, position: NGFJsonPosition) {
    this.ok = ok;
    this.root = root;
    this.failure = failure;
    this.args = args;
    this.position = position;
  }
}

/** 美化结果（把解析结果与格式化输出一起交给调用方） */
export class NGFJsonFormatResult {
  readonly ok: boolean;
  readonly formatted: string;
  readonly failure: NGFJsonFailure;
  readonly args: Array<string>;
  readonly position: NGFJsonPosition;

  constructor(ok: boolean, formatted: string, failure: NGFJsonFailure,
    args: Array<string>, position: NGFJsonPosition) {
    this.ok = ok;
    this.formatted = formatted;
    this.failure = failure;
    this.args = args;
    this.position = position;
  }
}

/** 解析器的单步结果：ok=false 时 message 说明原因、nextIndex 指向出错字符 */
/** JSON 解析失败的原因码（位置由 {@link JsonStep} 单独带出，不进码里） */
export enum NGFJsonFailure {
  NONE = 'none',
  ESCAPE_TRAILING = 'escape_trailing',
  UNICODE_INCOMPLETE = 'unicode_incomplete',
  UNICODE_BAD_HEX = 'unicode_bad_hex',
  ESCAPE_UNKNOWN = 'escape_unknown',
  STRING_UNTERMINATED = 'string_unterminated',
  NUMBER_NO_DIGITS = 'number_no_digits',
  NUMBER_LEADING_ZERO = 'number_leading_zero',
  NUMBER_FRACTION = 'number_fraction',
  NUMBER_EXPONENT = 'number_exponent',
  LITERAL_EXPECTED = 'literal_expected',
  ARRAY_UNCLOSED = 'array_unclosed',
  ARRAY_UNEXPECTED = 'array_unexpected',
  OBJECT_KEY_NOT_STRING = 'object_key_not_string',
  OBJECT_COLON = 'object_colon',
  OBJECT_UNCLOSED = 'object_unclosed',
  OBJECT_UNEXPECTED = 'object_unexpected',
  UNEXPECTED_END = 'unexpected_end',
  UNEXPECTED_CHAR = 'unexpected_char',
  TRAILING_CONTENT = 'trailing_content'
}

class JsonStep {
  readonly ok: boolean;
  readonly nextIndex: number;
  readonly node: NGFJsonNode | null;
  readonly failure: NGFJsonFailure;
  /** 资源文案的占位符参数 */
  readonly args: Array<string>;

  constructor(ok: boolean, nextIndex: number, node: NGFJsonNode | null,
    failure: NGFJsonFailure, args: Array<string>) {
    this.ok = ok;
    this.nextIndex = nextIndex;
    this.node = node;
    this.failure = failure;
    this.args = args;
  }

  static success(nextIndex: number, node: NGFJsonNode): JsonStep {
    return new JsonStep(true, nextIndex, node, NGFJsonFailure.NONE, []);
  }

  /**
   * 失败时不要文案，只要**码 + 参数**。
   *
   * 位置（nextIndex）单独带着走：它是给用户看的「第 N 行第 M 列」，
   * 拼进字符串就没法翻译了（中文说「第 1 行第 5 列」，英文说 "line 1, column 5"，
   * 连标点都不同）。
   */
  static failureCode(nextIndex: number, code: NGFJsonFailure,
    args: Array<string>): JsonStep {
    return new JsonStep(false, nextIndex, null, code, args);
  }
}

/** 把字符下标换算成 1 基的行列号（错误提示用） */
export function positionOf(text: string, index: number): NGFJsonPosition {
  let line: number = 1;
  let column: number = 1;
  const limit: number = index < text.length ? index : text.length;
  for (let i: number = 0; i < limit; i++) {
    if (text.charAt(i) === '\n') {
      line++;
      column = 1;
    } else {
      column++;
    }
  }
  return new NGFJsonPosition(line, column);
}

function isWhitespace(ch: string): boolean {
  return ch === ' ' || ch === '\t' || ch === '\n' || ch === '\r';
}

function isDigit(ch: string): boolean {
  return ch >= '0' && ch <= '9';
}

/** 是否全为十六进制字符（用于 \\uXXXX 的严格校验） */
function isHexText(value: string): boolean {
  if (value.length === 0) {
    return false;
  }
  for (let i: number = 0; i < value.length; i++) {
    const code: number = value.charCodeAt(i);
    const isDigitChar: boolean = code >= 48 && code <= 57;
    const isLowerHex: boolean = code >= 97 && code <= 102;
    if (!isDigitChar && !isLowerHex) {
      return false;
    }
  }
  return true;
}

function skipWhitespace(text: string, start: number): number {
  let index: number = start;
  while (index < text.length && isWhitespace(text.charAt(index))) {
    index++;
  }
  return index;
}

/** 解析一个 JSON 字符串字面量，返回转义解码后的内容与结束位置 */
function parseString(text: string, start: number): JsonStep {
  let index: number = start + 1;
  let value: string = '';
  while (index < text.length) {
    const ch: string = text.charAt(index);
    if (ch === '"') {
      return JsonStep.success(index + 1, NGFJsonNode.scalar(NGFJsonKind.STRING, value, value, false));
    }
    if (ch === '\\') {
      index++;
      if (index >= text.length) {
        return JsonStep.failureCode(index, NGFJsonFailure.ESCAPE_TRAILING, []);
      }
      const escape: string = text.charAt(index);
      if (escape === '"') {
        value += '"';
      } else if (escape === '\\') {
        value += '\\';
      } else if (escape === '/') {
        value += '/';
      } else if (escape === 'b') {
        value += '\b';
      } else if (escape === 'f') {
        value += '\f';
      } else if (escape === 'n') {
        value += '\n';
      } else if (escape === 'r') {
        value += '\r';
      } else if (escape === 't') {
        value += '\t';
      } else if (escape === 'u') {
        if (index + 4 >= text.length) {
          return JsonStep.failureCode(index, NGFJsonFailure.UNICODE_INCOMPLETE, []);
        }
        const hex: string = text.substring(index + 1, index + 5).toLowerCase();
        if (!isHexText(hex)) {
          // 必须逐字符校验：parseInt('12zz', 16) 会"成功"返回 18，只看 isNaN 会漏掉这类脏输入
          return JsonStep.failureCode(index, NGFJsonFailure.UNICODE_BAD_HEX, []);
        }
        const code: number = parseInt(hex, 16);
        value += String.fromCharCode(code);
        index += 4;
      } else {
        return JsonStep.failureCode(index, NGFJsonFailure.ESCAPE_UNKNOWN, [escape]);
      }
    } else {
      value += ch;
    }
    index++;
  }
  return JsonStep.failureCode(index, NGFJsonFailure.STRING_UNTERMINATED, []);
}

/** 解析数值。**保留原文**：JWT 的时间戳可能是大整数，转 number 会丢精度 */
function parseNumber(text: string, start: number): JsonStep {
  let index: number = start;
  if (index < text.length && text.charAt(index) === '-') {
    index++;
  }
  const digitsStart: number = index;
  while (index < text.length && isDigit(text.charAt(index))) {
    index++;
  }
  if (index === digitsStart) {
    return JsonStep.failureCode(start, NGFJsonFailure.NUMBER_NO_DIGITS, []);
  }
  const integerPart: string = text.substring(digitsStart, index);
  if (integerPart.length > 1 && integerPart.charAt(0) === '0') {
    return JsonStep.failureCode(digitsStart, NGFJsonFailure.NUMBER_LEADING_ZERO, []);
  }
  if (index < text.length && text.charAt(index) === '.') {
    index++;
    const fractionStart: number = index;
    while (index < text.length && isDigit(text.charAt(index))) {
      index++;
    }
    if (index === fractionStart) {
      return JsonStep.failureCode(fractionStart, NGFJsonFailure.NUMBER_FRACTION, []);
    }
  }
  if (index < text.length && (text.charAt(index) === 'e' || text.charAt(index) === 'E')) {
    index++;
    if (index < text.length && (text.charAt(index) === '+' || text.charAt(index) === '-')) {
      index++;
    }
    const exponentStart: number = index;
    while (index < text.length && isDigit(text.charAt(index))) {
      index++;
    }
    if (index === exponentStart) {
      return JsonStep.failureCode(exponentStart, NGFJsonFailure.NUMBER_EXPONENT, []);
    }
  }
  const raw: string = text.substring(start, index);
  return JsonStep.success(index, NGFJsonNode.scalar(NGFJsonKind.NUMBER, raw, '', false));
}

/** 解析 true / false / null */
function parseKeyword(text: string, start: number, keyword: string, kind: NGFJsonKind): JsonStep {
  const slice: string = text.substring(start, start + keyword.length);
  if (slice !== keyword) {
    return JsonStep.failureCode(start, NGFJsonFailure.LITERAL_EXPECTED, [keyword]);
  }
  return JsonStep.success(start + keyword.length,
    NGFJsonNode.scalar(kind, keyword, '', keyword === 'true'));
}

/** 解析数组 */
function parseArray(text: string, start: number): JsonStep {
  const items: NGFJsonNode[] = [];
  let index: number = skipWhitespace(text, start + 1);
  if (index < text.length && text.charAt(index) === ']') {
    return JsonStep.success(index + 1, new NGFJsonNode(NGFJsonKind.ARRAY, '', '', false, [], items));
  }
  while (true) {
    const step: JsonStep = parseValue(text, index);
    if (!step.ok || step.node === null) {
      return step;
    }
    items.push(step.node);
    index = skipWhitespace(text, step.nextIndex);
    if (index >= text.length) {
      return JsonStep.failureCode(index, NGFJsonFailure.ARRAY_UNCLOSED, []);
    }
    const ch: string = text.charAt(index);
    if (ch === ',') {
      index = skipWhitespace(text, index + 1);
      continue;
    }
    if (ch === ']') {
      return JsonStep.success(index + 1, new NGFJsonNode(NGFJsonKind.ARRAY, '', '', false, [], items));
    }
    return JsonStep.failureCode(index, NGFJsonFailure.ARRAY_UNEXPECTED, [ch]);
  }
}

/** 解析对象；重复键全部保留（由调用方决定取哪一个，解析器不做静默覆盖） */
function parseObject(text: string, start: number): JsonStep {
  const members: NGFJsonMember[] = [];
  let index: number = skipWhitespace(text, start + 1);
  if (index < text.length && text.charAt(index) === '}') {
    return JsonStep.success(index + 1, new NGFJsonNode(NGFJsonKind.OBJECT, '', '', false, members, []));
  }
  while (true) {
    if (index >= text.length || text.charAt(index) !== '"') {
      return JsonStep.failureCode(index, NGFJsonFailure.OBJECT_KEY_NOT_STRING, []);
    }
    const keyStep: JsonStep = parseString(text, index);
    if (!keyStep.ok || keyStep.node === null) {
      return keyStep;
    }
    index = skipWhitespace(text, keyStep.nextIndex);
    if (index >= text.length || text.charAt(index) !== ':') {
      return JsonStep.failureCode(index, NGFJsonFailure.OBJECT_COLON, []);
    }
    const valueStep: JsonStep = parseValue(text, index + 1);
    if (!valueStep.ok || valueStep.node === null) {
      return valueStep;
    }
    members.push(new NGFJsonMember(keyStep.node.stringValue, valueStep.node));
    index = skipWhitespace(text, valueStep.nextIndex);
    if (index >= text.length) {
      return JsonStep.failureCode(index, NGFJsonFailure.OBJECT_UNCLOSED, []);
    }
    const ch: string = text.charAt(index);
    if (ch === ',') {
      index = skipWhitespace(text, index + 1);
      continue;
    }
    if (ch === '}') {
      return JsonStep.success(index + 1, new NGFJsonNode(NGFJsonKind.OBJECT, '', '', false, members, []));
    }
    return JsonStep.failureCode(index, NGFJsonFailure.OBJECT_UNEXPECTED, [ch]);
  }
}

/** 解析任意 JSON 值 */
function parseValue(text: string, start: number): JsonStep {
  const index: number = skipWhitespace(text, start);
  if (index >= text.length) {
    return JsonStep.failureCode(index, NGFJsonFailure.UNEXPECTED_END, []);
  }
  const ch: string = text.charAt(index);
  if (ch === '{') {
    return parseObject(text, index);
  }
  if (ch === '[') {
    return parseArray(text, index);
  }
  if (ch === '"') {
    return parseString(text, index);
  }
  if (ch === 't') {
    return parseKeyword(text, index, 'true', NGFJsonKind.BOOLEAN);
  }
  if (ch === 'f') {
    return parseKeyword(text, index, 'false', NGFJsonKind.BOOLEAN);
  }
  if (ch === 'n') {
    return parseKeyword(text, index, 'null', NGFJsonKind.NULL);
  }
  if (ch === '-' || isDigit(ch)) {
    return parseNumber(text, index);
  }
  return JsonStep.failureCode(index, NGFJsonFailure.UNEXPECTED_CHAR, [ch]);
}

/**
 * 解析一段 JSON 文本。
 *
 * 只接受「一个完整的值」，后面不允许再有多余内容——JWT 载荷如果是
 * `{"a":1}} `这种尾巴，必须报错而不是假装解析成功。
 */
export function parseJson(text: string): NGFJsonParseResult {
  const step: JsonStep = parseValue(text, 0);
  if (!step.ok || step.node === null) {
    return new NGFJsonParseResult(false, null, step.failure, step.args,
    positionOf(text, step.nextIndex));
  }
  const rest: number = skipWhitespace(text, step.nextIndex);
  if (rest < text.length) {
    return new NGFJsonParseResult(false, null, NGFJsonFailure.TRAILING_CONTENT, [],
      positionOf(text, rest));
  }
  return new NGFJsonParseResult(true, step.node, NGFJsonFailure.NONE, [],
      new NGFJsonPosition(1, 1));
}

/** 字符串重新转义成 JSON 字面量（美化输出用） */
function escapeJsonString(value: string): string {
  let escaped: string = '';
  for (let i: number = 0; i < value.length; i++) {
    const ch: string = value.charAt(i);
    const code: number = value.charCodeAt(i);
    if (ch === '"') {
      escaped += '\\"';
    } else if (ch === '\\') {
      escaped += '\\\\';
    } else if (ch === '\n') {
      escaped += '\\n';
    } else if (ch === '\r') {
      escaped += '\\r';
    } else if (ch === '\t') {
      escaped += '\\t';
    } else if (ch === '\b') {
      escaped += '\\b';
    } else if (ch === '\f') {
      escaped += '\\f';
    } else if (code < 0x20) {
      // 其余控制字符只能用 \uXXXX 表示
      const hex: string = code.toString(16);
      escaped += '\\u' + '0000'.substring(hex.length) + hex;
    } else {
      escaped += ch;
    }
  }
  return escaped;
}

function indentOf(size: number): string {
  let spaces: string = '';
  for (let i: number = 0; i < size; i++) {
    spaces += ' ';
  }
  return spaces;
}

/**
 * 美化 JSON 树。
 *
 * 数值直接用解析时保留的原文，绝不经过 number 往返——否则 `exp: 9007199254740993`
 * 这种值会在「美化」这一步被悄悄改掉，而用户正是要拿它做比对。
 */
export function formatJsonNode(node: NGFJsonNode, indentSize: number): string {
  const unit: string = indentOf(indentSize < 0 ? 0 : indentSize);
  return formatJsonNodeAt(node, unit, '');
}

function formatJsonNodeAt(node: NGFJsonNode, unit: string, indent: string): string {
  if (node.kind === NGFJsonKind.OBJECT) {
    if (node.members.length === 0) {
      return '{}';
    }
    const inner: string = indent + unit;
    let body: string = '';
    for (let i: number = 0; i < node.members.length; i++) {
      const member: NGFJsonMember = node.members[i];
      body += inner + '"' + escapeJsonString(member.key) + '": '
        + formatJsonNodeAt(member.value, unit, inner);
      if (i < node.members.length - 1) {
        body += ',';
      }
      body += '\n';
    }
    return '{\n' + body + indent + '}';
  }
  if (node.kind === NGFJsonKind.ARRAY) {
    if (node.items.length === 0) {
      return '[]';
    }
    const inner: string = indent + unit;
    let body: string = '';
    for (let i: number = 0; i < node.items.length; i++) {
      body += inner + formatJsonNodeAt(node.items[i], unit, inner);
      if (i < node.items.length - 1) {
        body += ',';
      }
      body += '\n';
    }
    return '[\n' + body + indent + ']';
  }
  if (node.kind === NGFJsonKind.STRING) {
    return '"' + escapeJsonString(node.stringValue) + '"';
  }
  return node.text;
}

/** 解析并美化；失败时返回带行列号的错误信息 */
export function formatJsonText(text: string, indentSize: number): NGFJsonFormatResult {
  const parsed: NGFJsonParseResult = parseJson(text);
  if (!parsed.ok || parsed.root === null) {
    return new NGFJsonFormatResult(false, '', parsed.failure, parsed.args, parsed.position);
  }
  return new NGFJsonFormatResult(true, formatJsonNode(parsed.root, indentSize),
      NGFJsonFailure.NONE, [], parsed.position);
}

/**
 * 取**顶层**对象成员里的数值原文；不存在、不是数值或不是对象时返回空串。
 *
 * 只认顶层：JWT 的 `exp`/`iat`/`nbf` 都是顶层声明，往下钻只会把
 * 「嵌套结构里的同名键」误当成声明时间。
 */
export function findTopLevelNumberText(root: NGFJsonNode, key: string): string {
  if (root.kind !== NGFJsonKind.OBJECT) {
    return '';
  }
  for (let i: number = 0; i < root.members.length; i++) {
    const member: NGFJsonMember = root.members[i];
    if (member.key === key && member.value.kind === NGFJsonKind.NUMBER) {
      return member.value.text;
    }
  }
  return '';
}

/** 取顶层字符串成员；不存在返回空串 */
export function findTopLevelStringText(root: NGFJsonNode, key: string): string {
  if (root.kind !== NGFJsonKind.OBJECT) {
    return '';
  }
  for (let i: number = 0; i < root.members.length; i++) {
    const member: NGFJsonMember = root.members[i];
    if (member.key === key && member.value.kind === NGFJsonKind.STRING) {
      return member.value.stringValue;
    }
  }
  return '';
}