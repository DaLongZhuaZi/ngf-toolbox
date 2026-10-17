/**
 * JSON 工具的**纯逻辑层**。
 *
 * ## 为什么不用 JSON.parse + JSON.stringify
 *
 * 「格式化 JSON」最省事的写法是 parse 一次再 stringify 回去，但那样会**改坏数字**：
 * JSON.parse 把数字变成双精度浮点，12345678901234567890 会变成 12345678901234567000，
 * 而这类大整数恰恰经常出现在本工具的输入里（雪花 ID、纳秒时间戳、区块链数值）。
 * 用户拿格式化工具是为了看清楚结构，不是为了被悄悄改数据。
 *
 * 因此本文件自己写了一个 JSON 解析器，把数字**按原样字面量**保留下来，
 * 输出时原样写回。代价是不做数值计算——本工具也确实不需要。
 *
 * ## 为什么自己写解析器还有第二个好处
 *
 * JSON.parse 报错只说「Unexpected token } in JSON at position 12」，
 * 而产品定义稿 §四 要求「错误就地红字说明（JSON/正则的错误定位到位置）」。
 * 自己解析才能给出中文提示 + 行号列号（例如「对象成员之间缺少逗号（第 3 行第 5 列）」）。
 *
 * @module tools/json-toolkit/JsonLogic
 */

/**
 * 允许的最大嵌套层级。
 *
 * 为什么要设限：解析是递归的，几十万层的 [[[[...]]]] 会让调用栈溢出，
 * 而栈溢出是**捕获不到**的崩溃（整个应用挂掉），不是一条红字错误。
 * 真实数据极少超过 128 层，超了就是恶意或损坏的输入，明确报错更好。
 */
export const JSON_MAX_DEPTH: number = 128;

/** 缩进空格数的允许范围（页面给滑杆/输入框时用同一份口径） */
export const JSON_MIN_INDENT: number = 0;
export const JSON_MAX_INDENT: number = 8;
export const JSON_DEFAULT_INDENT: number = 2;

/** JSON 值的种类 */
export enum JsonNodeKind {
  OBJECT = 'object',
  ARRAY = 'array',
  STRING = 'string',
  NUMBER = 'number',
  BOOLEAN = 'boolean',
  NULL = 'null'
}

/**
 * 解析错误。
 *
 * line / column 都是**从 1 开始**的（给用户看的），position 是从 0 开始的字符下标
 * （与 JS 口径一致，供程序使用）。三者都留着，是为了让页面既能显示「第 3 行第 5 列」，
 * 也能把光标定位到具体字符。
 */
/** JSON 解析失败的原因码 */
export enum JsonErrorCode {
  NONE = 'none',
  /** 输入为空 */
  EMPTY = 'empty',
  /** JSON 结束后还有多余内容 */
  TRAILING = 'trailing',
  /** 什么都没解析出来 */
  NOTHING = 'nothing',
  /** 嵌套层级超限 */
  TOO_DEEP = 'too_deep',
  /** 内容意外结束 */
  UNEXPECTED_END = 'unexpected_end',
  /** 字符串用了单引号 */
  SINGLE_QUOTE_STRING = 'single_quote_string',
  /** 出现了注释 */
  COMMENT = 'comment',
  /** 无法识别的字面量（值位置） */
  UNKNOWN_LITERAL = 'unknown_literal',
  /** 无法识别的关键字（true/false/null 位置） */
  UNKNOWN_KEYWORD = 'unknown_keyword',
  /** 字符串以反斜杠结尾 */
  STRING_BACKSLASH_END = 'string_backslash_end',
  /** 字符串里直接出现控制字符 */
  STRING_CONTROL_CHAR = 'string_control_char',
  /** 字符串没有闭合 */
  STRING_UNTERMINATED = 'string_unterminated',
  NUMBER_LEADING_ZERO = 'number_leading_zero',
  NUMBER_MINUS = 'number_minus',
  NUMBER_FRACTION = 'number_fraction',
  NUMBER_EXPONENT = 'number_exponent',
  OBJECT_UNCLOSED = 'object_unclosed',
  OBJECT_KEY_SINGLE_QUOTE = 'object_key_single_quote',
  OBJECT_KEY_NOT_STRING = 'object_key_not_string',
  OBJECT_COLON = 'object_colon',
  OBJECT_TRAILING_COMMA = 'object_trailing_comma',
  OBJECT_MISSING_COMMA = 'object_missing_comma',
  ARRAY_TRAILING_COMMA = 'array_trailing_comma',
  ARRAY_UNCLOSED = 'array_unclosed',
  ARRAY_MISSING_COMMA = 'array_missing_comma',
  // 下面三个是**字符串反转义**专用的（JsonStringResult 复用本枚举当失败码）：
  // 它们不是「解析 JSON 文档」时的错误，而是「还原一段转义文本」时的错误。
  /** \u 转义不完整（不足 4 位十六进制） */
  UNICODE_INCOMPLETE = 'unicode_incomplete',
  /** \u 转义里出现了非十六进制字符 */
  UNICODE_BAD_HEX = 'unicode_bad_hex',
  /** 不支持的转义写法 */
  ESCAPE_UNSUPPORTED = 'escape_unsupported'
}

/**
 * 解析错误。
 *
 * **只给码 + 参数 + 位置**，不给拼好的句子。
 * 位置尤其不能拼进去：中文写「第 3 行第 5 列」，英文写 "line 3, column 5"，
 * 连标点都不同。line / column 从 1 开始（给人看），position 从 0 开始（给程序用）。
 */
export class JsonError {
  readonly code: JsonErrorCode;
  /** 资源文案的占位符参数 */
  readonly args: Array<string>;
  readonly line: number;
  readonly column: number;
  readonly position: number;

  constructor(code: JsonErrorCode, args: Array<string>, line: number, column: number,
    position: number) {
    this.code = code;
    this.args = args;
    this.line = line;
    this.column = column;
    this.position = position;
  }

  static none(): JsonError {
    return new JsonError(JsonErrorCode.NONE, [], 0, 0, 0);
  }
}

/**
 * 解析出来的 JSON 节点。
 *
 * 刻意**不**把数字转成 number：raw 是原始字面量文本，格式化时原样写回。
 * 对象/数组的子节点也只存结构，不做任何求值。
 */
export class JsonNode {
  readonly kind: JsonNodeKind;
  /** 原始字面量：数字是原样文本，字符串含两端引号，true/false/null 是关键字本身 */
  readonly raw: string;
  /** 仅 BOOLEAN 有意义 */
  readonly booleanValue: boolean;
  /** 仅 OBJECT 有意义（保持出现顺序，重复键按出现顺序都在这里） */
  readonly members: Array<JsonMember>;
  /** 仅 ARRAY 有意义 */
  readonly items: Array<JsonNode>;
  readonly line: number;
  readonly column: number;

  constructor(kind: JsonNodeKind, raw: string, booleanValue: boolean, members: Array<JsonMember>,
              items: Array<JsonNode>, line: number, column: number) {
    this.kind = kind;
    this.raw = raw;
    this.booleanValue = booleanValue;
    this.members = members;
    this.items = items;
    this.line = line;
    this.column = column;
  }
}

/** 对象的一个成员 */
export class JsonMember {
  /** 解码后的键（转义已还原），用于判重与展示 */
  readonly key: string;
  /** 键的原始写法（含引号），格式化时原样写回，避免把 \\u4e2d 改写成「中」 */
  readonly keyRaw: string;
  readonly value: JsonNode;
  readonly line: number;
  readonly column: number;

  constructor(key: string, keyRaw: string, value: JsonNode, line: number, column: number) {
    this.key = key;
    this.keyRaw = keyRaw;
    this.value = value;
    this.line = line;
    this.column = column;
  }
}

/** 解析结果。ok=false 时 root 为 null、error 非 null。 */
export class JsonParseResult {
  readonly ok: boolean;
  readonly error: JsonError | null;
  readonly root: JsonNode | null;
  /** 出现过的重复键（JSON 允许，但多数语言解析后只保留最后一个，值得提示） */
  readonly duplicateKeys: Array<string>;

  constructor(ok: boolean, error: JsonError | null, root: JsonNode | null, duplicateKeys: Array<string>) {
    this.ok = ok;
    this.error = error;
    this.root = root;
    this.duplicateKeys = duplicateKeys;
  }

  // errorText() 已移除：拼「错误 + 位置」是显示逻辑，归 UI 层
  // （见 JsonMessages.errorTextOf）。
}

/** 格式化/压缩结果 */
export class JsonFormatResult {
  readonly ok: boolean;
  readonly text: string;
  readonly error: JsonError | null;
  /** 输出使用的缩进空格数（压缩时是 0） */
  readonly indent: number;

  constructor(ok: boolean, text: string, error: JsonError | null, indent: number) {
    this.ok = ok;
    this.text = text;
    this.error = error;
    this.indent = indent;
  }

}

/** 字符串转义/反转义结果 */
/** 字符串反转义失败的原因码（与解析错误同属转义问题，复用 JsonErrorCode 的对应几项） */
export class JsonStringResult {
  readonly ok: boolean;
  readonly text: string;
  readonly failure: JsonErrorCode;
  readonly args: Array<string>;

  constructor(ok: boolean, text: string, failure: JsonErrorCode, args: Array<string>) {
    this.ok = ok;
    this.text = text;
    this.failure = failure;
    this.args = args;
  }

  static fail(failure: JsonErrorCode, args: Array<string>): JsonStringResult {
    return new JsonStringResult(false, '', failure, args);
  }
}

/** 十六进制字符转数字，非法返回 -1 */
function hexValue(ch: string): number {
  if (ch >= '0' && ch <= '9') {
    return ch.charCodeAt(0) - 48;
  }
  if (ch >= 'a' && ch <= 'f') {
    return ch.charCodeAt(0) - 87;
  }
  if (ch >= 'A' && ch <= 'F') {
    return ch.charCodeAt(0) - 55;
  }
  return -1;
}

function isWhitespace(ch: string): boolean {
  return ch === ' ' || ch === '\t' || ch === '\n' || ch === '\r';
}

/**
 * 把字符串内容转成 JSON 字符串字面量里该有的转义形式（**不含两端引号**）。
 *
 * 取舍：只转义 JSON 规定的必须转义字符（引号、反斜杠、控制字符），
 * 中文与 emoji 保持原样。把它们转成 \\uXXXX 虽然也合法，但会让输出变得没法读，
 * 而「看得懂」正是用户打开这个工具的目的。
 */
export function escapeJsonString(text: string): string {
  let out: string = '';
  for (let i: number = 0; i < text.length; i++) {
    const ch: string = text.charAt(i);
    if (ch === '"') {
      out = out + '\\"';
    } else if (ch === '\\') {
      out = out + '\\\\';
    } else if (ch === '\n') {
      out = out + '\\n';
    } else if (ch === '\r') {
      out = out + '\\r';
    } else if (ch === '\t') {
      out = out + '\\t';
    } else if (ch === '\b') {
      out = out + '\\b';
    } else if (ch === '\f') {
      out = out + '\\f';
    } else if (ch.charCodeAt(0) < 0x20) {
      out = out + '\\u' + padHex4(ch.charCodeAt(0));
    } else {
      out = out + ch;
    }
  }
  return out;
}

/** 四位大写十六进制（\\uXXXX 的 XXXX 部分） */
function padHex4(code: number): string {
  let hex: string = code.toString(16).toUpperCase();
  while (hex.length < 4) {
    hex = '0' + hex;
  }
  return hex;
}

const HEX_DIGITS: string = '0123456789ABCDEF';

/** 把字符串内容里的 JSON 转义还原成真实字符（**不含两端引号**） */
export function unescapeJsonString(text: string): JsonStringResult {
  let out: string = '';
  let i: number = 0;
  while (i < text.length) {
    const ch: string = text.charAt(i);
    if (ch !== '\\') {
      out = out + ch;
      i++;
      continue;
    }
    if (i + 1 >= text.length) {
      return JsonStringResult.fail(JsonErrorCode.STRING_BACKSLASH_END, []);
    }
    const marker: string = text.charAt(i + 1);
    if (marker === '"') {
      out = out + '"';
      i = i + 2;
    } else if (marker === '\\') {
      out = out + '\\';
      i = i + 2;
    } else if (marker === '/') {
      out = out + '/';
      i = i + 2;
    } else if (marker === 'b') {
      out = out + '\b';
      i = i + 2;
    } else if (marker === 'f') {
      out = out + '\f';
      i = i + 2;
    } else if (marker === 'n') {
      out = out + '\n';
      i = i + 2;
    } else if (marker === 'r') {
      out = out + '\r';
      i = i + 2;
    } else if (marker === 't') {
      out = out + '\t';
      i = i + 2;
    } else if (marker === 'u') {
      if (i + 6 > text.length) {
        return JsonStringResult.fail(JsonErrorCode.UNICODE_INCOMPLETE, []);
      }
      let code: number = 0;
      for (let k: number = 0; k < 4; k++) {
        const digit: number = hexValue(text.charAt(i + 2 + k));
        if (digit < 0) {
          return JsonStringResult.fail(JsonErrorCode.UNICODE_BAD_HEX,
            [text.substring(i, i + 6 > text.length ? text.length : i + 6)]);
        }
        code = code * 16 + digit;
      }
      out = out + String.fromCharCode(code);
      i = i + 6;
    } else {
      return JsonStringResult.fail(JsonErrorCode.ESCAPE_UNSUPPORTED, [marker]);
    }
  }
  return new JsonStringResult(true, out, JsonErrorCode.NONE, []);
}

/**
 * JSON 解析器。
 *
 * 逐字符扫描的递归下降解析：JSON 的语法小到不值得引入任何库，
 * 而「自己写」换来的是原样保留数字与中文错误定位。
 */
class JsonParser {
  private readonly text: string;
  private pos: number = 0;
  private failure: JsonError | null = null;
  private duplicates: Array<string> = [];

  constructor(text: string) {
    this.text = text;
  }

  parseDocument(): JsonParseResult {
    // UTF-8 BOM：从 Windows 记事本另存的文件常带它，别的工具能忽略，我们也忽略
    if (this.text.length > 0 && this.text.charCodeAt(0) === 0xFEFF) {
      this.pos = 1;
    }
    this.skipWhitespace();
    if (this.pos >= this.text.length) {
      return new JsonParseResult(false, this.errorAt(JsonErrorCode.EMPTY, [], this.pos), null, []);
    }
    const root: JsonNode | null = this.parseValue(0);
    if (this.failure !== null) {
      return new JsonParseResult(false, this.failure, null, this.duplicates);
    }
    this.skipWhitespace();
    if (this.pos < this.text.length) {
      return new JsonParseResult(false, this.errorAt(JsonErrorCode.TRAILING, [], this.pos), null, this.duplicates);
    }
    if (root === null) {
      return new JsonParseResult(false, this.errorAt(JsonErrorCode.NOTHING, [], this.pos), null, this.duplicates);
    }
    return new JsonParseResult(true, null, root, this.duplicates);
  }

  private skipWhitespace(): void {
    while (this.pos < this.text.length && isWhitespace(this.text.charAt(this.pos))) {
      this.pos++;
    }
  }

  private charAt(index: number): string {
    if (index < 0 || index >= this.text.length) {
      return '';
    }
    return this.text.charAt(index);
  }

  private errorAt(code: JsonErrorCode, args: Array<string>, position: number): JsonError {
    let line: number = 1;
    let column: number = 1;
    const limit: number = position < this.text.length ? position : this.text.length;
    for (let i: number = 0; i < limit; i++) {
      if (this.text.charAt(i) === '\n') {
        line++;
        column = 1;
      } else {
        column++;
      }
    }
    return new JsonError(code, args, line, column, position);
  }

  private failAt(code: JsonErrorCode, args: Array<string>, position: number): JsonError {
    const error: JsonError = this.errorAt(code, args, position);
    if (this.failure === null) {
      this.failure = error;
    }
    return error;
  }

  /** 解析一个值；出错时返回 null 并把错误记在 failure 上 */
  private parseValue(depth: number): JsonNode | null {
    if (depth > JSON_MAX_DEPTH) {
      this.failAt(JsonErrorCode.TOO_DEEP, [String(JSON_MAX_DEPTH)], this.pos);
      return null;
    }
    this.skipWhitespace();
    if (this.pos >= this.text.length) {
      this.failAt(JsonErrorCode.UNEXPECTED_END, [], this.pos);
      return null;
    }
    const ch: string = this.text.charAt(this.pos);
    if (ch === '{') {
      return this.parseObject(depth);
    }
    if (ch === '[') {
      return this.parseArray(depth);
    }
    if (ch === '"') {
      return this.parseStringNode();
    }
    if (ch === "'") {
      this.failAt(JsonErrorCode.SINGLE_QUOTE_STRING, [], this.pos);
      return null;
    }
    if (ch === '/' && (this.charAt(this.pos + 1) === '/' || this.charAt(this.pos + 1) === '*')) {
      this.failAt(JsonErrorCode.COMMENT, [], this.pos);
      return null;
    }
    if (ch === '-' || (ch >= '0' && ch <= '9')) {
      return this.parseNumberNode();
    }
    if (ch === 't' || ch === 'f' || ch === 'n') {
      return this.parseKeywordNode();
    }
    this.failAt(JsonErrorCode.UNKNOWN_LITERAL, [], this.pos);
    return null;
  }

  private parseKeywordNode(): JsonNode | null {
    const start: number = this.pos;
    const rest: string = this.text.substring(this.pos);
    if (rest.indexOf('true') === 0) {
      this.pos = this.pos + 4;
      return new JsonNode(JsonNodeKind.BOOLEAN, 'true', true, [], [], 0, 0);
    }
    if (rest.indexOf('false') === 0) {
      this.pos = this.pos + 5;
      return new JsonNode(JsonNodeKind.BOOLEAN, 'false', false, [], [], 0, 0);
    }
    if (rest.indexOf('null') === 0) {
      this.pos = this.pos + 4;
      return new JsonNode(JsonNodeKind.NULL, 'null', false, [], [], 0, 0);
    }
    this.failAt(JsonErrorCode.UNKNOWN_KEYWORD, [], start);
    return null;
  }

  private parseStringNode(): JsonNode | null {
    const raw: string | null = this.scanStringLiteral();
    if (raw === null) {
      return null;
    }
    return new JsonNode(JsonNodeKind.STRING, raw, false, [], [], 0, 0);
  }

  /** 扫描一个字符串字面量，返回含引号的原文；出错返回 null */
  private scanStringLiteral(): string | null {
    const start: number = this.pos;
    this.pos++;
    let closed: boolean = false;
    while (this.pos < this.text.length) {
      const ch: string = this.text.charAt(this.pos);
      if (ch === '"') {
        this.pos++;
        closed = true;
        break;
      }
      if (ch === '\\') {
        // 转义序列整体跳过：\" 不能被当成字符串结束
        if (this.pos + 1 >= this.text.length) {
          this.failAt(JsonErrorCode.STRING_BACKSLASH_END, [], this.pos);
          return null;
        }
        this.pos = this.pos + 2;
        continue;
      }
      if (ch.charCodeAt(0) < 0x20) {
        this.failAt(JsonErrorCode.STRING_CONTROL_CHAR, [], this.pos);
        return null;
      }
      this.pos++;
    }
    if (!closed) {
      this.failAt(JsonErrorCode.STRING_UNTERMINATED, [], start);
      return null;
    }
    return this.text.substring(start, this.pos);
  }

  private parseNumberNode(): JsonNode | null {
    const start: number = this.pos;
    if (this.charAt(this.pos) === '-') {
      this.pos++;
    }
    if (this.charAt(this.pos) === '0') {
      this.pos++;
      const next: string = this.charAt(this.pos);
      if (next >= '0' && next <= '9') {
        this.failAt(JsonErrorCode.NUMBER_LEADING_ZERO, [], start);
        return null;
      }
    } else if (this.charAt(this.pos) >= '1' && this.charAt(this.pos) <= '9') {
      while (this.charAt(this.pos) >= '0' && this.charAt(this.pos) <= '9') {
        this.pos++;
      }
    } else {
      this.failAt(JsonErrorCode.NUMBER_MINUS, [], start);
      return null;
    }
    if (this.charAt(this.pos) === '.') {
      this.pos++;
      let digits: number = 0;
      while (this.charAt(this.pos) >= '0' && this.charAt(this.pos) <= '9') {
        this.pos++;
        digits++;
      }
      if (digits === 0) {
        this.failAt(JsonErrorCode.NUMBER_FRACTION, [], start);
        return null;
      }
    }
    const expMarker: string = this.charAt(this.pos);
    if (expMarker === 'e' || expMarker === 'E') {
      this.pos++;
      const sign: string = this.charAt(this.pos);
      if (sign === '+' || sign === '-') {
        this.pos++;
      }
      let expDigits: number = 0;
      while (this.charAt(this.pos) >= '0' && this.charAt(this.pos) <= '9') {
        this.pos++;
        expDigits++;
      }
      if (expDigits === 0) {
        this.failAt(JsonErrorCode.NUMBER_EXPONENT, [], start);
        return null;
      }
    }
    const raw: string = this.text.substring(start, this.pos);
    return new JsonNode(JsonNodeKind.NUMBER, raw, false, [], [], 0, 0);
  }

  private parseObject(depth: number): JsonNode | null {
    const start: number = this.pos;
    this.pos++;
    const members: Array<JsonMember> = [];
    this.skipWhitespace();
    if (this.charAt(this.pos) === '}') {
      this.pos++;
      return new JsonNode(JsonNodeKind.OBJECT, this.text.substring(start, this.pos), false, members, [], 0, 0);
    }
    while (true) {
      this.skipWhitespace();
      const keyStart: number = this.pos;
      const keyChar: string = this.charAt(this.pos);
      if (keyChar === '') {
        this.failAt(JsonErrorCode.OBJECT_UNCLOSED, [], start);
        return null;
      }
      if (keyChar !== '"') {
        if (keyChar === "'") {
          this.failAt(JsonErrorCode.OBJECT_KEY_SINGLE_QUOTE, [], this.pos);
        } else {
          this.failAt(JsonErrorCode.OBJECT_KEY_NOT_STRING, [], this.pos);
        }
        return null;
      }
      const keyRaw: string | null = this.scanStringLiteral();
      if (keyRaw === null) {
        return null;
      }
      const keyInner: string = keyRaw.substring(1, keyRaw.length - 1);
      const decodedKey: JsonStringResult = unescapeJsonString(keyInner);
      const keyText: string = decodedKey.ok ? decodedKey.text : keyInner;
      for (let i: number = 0; i < members.length; i++) {
        if (members[i].key === keyText) {
          this.duplicates.push(keyText);
          break;
        }
      }
      this.skipWhitespace();
      if (this.charAt(this.pos) !== ':') {
        this.failAt(JsonErrorCode.OBJECT_COLON, [], this.pos);
        return null;
      }
      this.pos++;
      const value: JsonNode | null = this.parseValue(depth + 1);
      if (value === null) {
        return null;
      }
      members.push(new JsonMember(keyText, keyRaw, value, 0, keyStart));
      this.skipWhitespace();
      const separator: string = this.charAt(this.pos);
      if (separator === ',') {
        this.pos++;
        this.skipWhitespace();
        if (this.charAt(this.pos) === '}') {
          this.failAt(JsonErrorCode.OBJECT_TRAILING_COMMA, [], this.pos);
          return null;
        }
        continue;
      }
      if (separator === '}') {
        this.pos++;
        return new JsonNode(JsonNodeKind.OBJECT, this.text.substring(start, this.pos), false, members, [], 0, 0);
      }
      if (separator === '') {
        this.failAt(JsonErrorCode.OBJECT_UNCLOSED, [], start);
        return null;
      }
      this.failAt(JsonErrorCode.OBJECT_MISSING_COMMA, [], this.pos);
      return null;
    }
  }

  private parseArray(depth: number): JsonNode | null {
    const start: number = this.pos;
    this.pos++;
    const items: Array<JsonNode> = [];
    this.skipWhitespace();
    if (this.charAt(this.pos) === ']') {
      this.pos++;
      return new JsonNode(JsonNodeKind.ARRAY, this.text.substring(start, this.pos), false, [], items, 0, 0);
    }
    while (true) {
      const item: JsonNode | null = this.parseValue(depth + 1);
      if (item === null) {
        return null;
      }
      items.push(item);
      this.skipWhitespace();
      const separator: string = this.charAt(this.pos);
      if (separator === ',') {
        this.pos++;
        this.skipWhitespace();
        if (this.charAt(this.pos) === ']') {
          this.failAt(JsonErrorCode.ARRAY_TRAILING_COMMA, [], this.pos);
          return null;
        }
        continue;
      }
      if (separator === ']') {
        this.pos++;
        return new JsonNode(JsonNodeKind.ARRAY, this.text.substring(start, this.pos), false, [], items, 0, 0);
      }
      if (separator === '') {
        this.failAt(JsonErrorCode.ARRAY_UNCLOSED, [], start);
        return null;
      }
      this.failAt(JsonErrorCode.ARRAY_MISSING_COMMA, [], this.pos);
      return null;
    }
  }
}

/** 解析 JSON 文本（只校验并建树，不产出格式化结果） */
export function parseJson(text: string): JsonParseResult {
  const parser: JsonParser = new JsonParser(text);
  return parser.parseDocument();
}

/** 把缩进值夹到合法范围 */
export function clampIndent(indent: number): number {
  if (indent < JSON_MIN_INDENT) {
    return JSON_MIN_INDENT;
  }
  if (indent > JSON_MAX_INDENT) {
    return JSON_MAX_INDENT;
  }
  return Math.floor(indent);
}

/** 生成 depth 层缩进的空格串 */
function indentText(indent: number, depth: number): string {
  if (indent <= 0 || depth <= 0) {
    return '';
  }
  let text: string = '';
  const total: number = indent * depth;
  for (let i: number = 0; i < total; i++) {
    text = text + ' ';
  }
  return text;
}

/**
 * 把节点渲染成文本。
 *
 * 用「往数组里塞片段、最后 join」而不是一路 a += b：后者在几百 KB 的 JSON 上
 * 会产生大量中间字符串，格式化大文件时明显变慢。
 */
function renderNode(node: JsonNode, indent: number, depth: number, out: Array<string>, compact: boolean): void {
  if (node.kind === JsonNodeKind.OBJECT) {
    if (node.members.length === 0) {
      out.push('{}');
      return;
    }
    out.push('{');
    for (let i: number = 0; i < node.members.length; i++) {
      const member: JsonMember = node.members[i];
      if (!compact) {
        out.push('\n');
        out.push(indentText(indent, depth + 1));
      }
      out.push(member.keyRaw);
      // 压缩模式下冒号后面不留空格：'{"a":1}' 而不是 '{"a": 1}'
      out.push(compact ? ':' : ': ');
      renderNode(member.value, indent, depth + 1, out, compact);
      if (i < node.members.length - 1) {
        out.push(',');
      }
    }
    if (!compact) {
      out.push('\n');
      out.push(indentText(indent, depth));
    }
    out.push('}');
    return;
  }
  if (node.kind === JsonNodeKind.ARRAY) {
    if (node.items.length === 0) {
      out.push('[]');
      return;
    }
    out.push('[');
    for (let i: number = 0; i < node.items.length; i++) {
      if (!compact) {
        out.push('\n');
        out.push(indentText(indent, depth + 1));
      }
      renderNode(node.items[i], indent, depth + 1, out, compact);
      if (i < node.items.length - 1) {
        out.push(',');
      }
    }
    if (!compact) {
      out.push('\n');
      out.push(indentText(indent, depth));
    }
    out.push(']');
    return;
  }
  // 标量：原样写出（字符串含引号、数字是原始字面量）
  out.push(node.raw);
}

/**
 * 格式化（缩进美化）。
 *
 * indent 会被夹到 0..8：0 表示「换行但不缩进」，仍比压缩好读；
 * 想要完全压成一行请用 {@link minifyJson}。
 */
export function formatJson(text: string, indent: number): JsonFormatResult {
  const parsed: JsonParseResult = parseJson(text);
  if (!parsed.ok || parsed.root === null) {
    return new JsonFormatResult(false, '', parsed.error, 0);
  }
  const safeIndent: number = clampIndent(indent);
  const out: Array<string> = [];
  renderNode(parsed.root, safeIndent, 0, out, false);
  return new JsonFormatResult(true, out.join(''), null, safeIndent);
}

/** 压缩成一行（去掉所有非必要空白，冒号后也不留空格） */
export function minifyJson(text: string): JsonFormatResult {
  const parsed: JsonParseResult = parseJson(text);
  if (!parsed.ok || parsed.root === null) {
    return new JsonFormatResult(false, '', parsed.error, 0);
  }
  const out: Array<string> = [];
  renderNode(parsed.root, 0, 0, out, true);
  return new JsonFormatResult(true, out.join(''), null, 0);
}

/**
 * 根节点的一句话概要的**结构**（措辞在 UI 层）。
 *
 * 原先这里直接拼中文（'顶层是对象，共 3 个键'）。改成结构之后，
 * 「几个键」「多长」这些数字原样带出去——中文说「共 3 个键」，英文说
 * "3 keys at the top level"，语序与量词都不同。
 *
 * root 为 null 时 kind 是 NONE。
 */
export class JsonSummary {
  readonly kind: JsonNodeKind;
  /** kind 为 NONE 时为 true（表示没有内容） */
  readonly empty: boolean;
  /** 对象的键数 / 数组的项数 / 字符串长度；其它种类为 0 */
  readonly count: number;
  /** 数字与布尔值的原文（页面原样展示） */
  readonly raw: string;

  constructor(kind: JsonNodeKind, empty: boolean, count: number, raw: string) {
    this.kind = kind;
    this.empty = empty;
    this.count = count;
    this.raw = raw;
  }
}

export function describeJsonRoot(root: JsonNode | null): JsonSummary {
  if (root === null) {
    return new JsonSummary(JsonNodeKind.NULL, true, 0, '');
  }
  if (root.kind === JsonNodeKind.OBJECT) {
    return new JsonSummary(root.kind, false, root.members.length, '');
  }
  if (root.kind === JsonNodeKind.ARRAY) {
    return new JsonSummary(root.kind, false, root.items.length, '');
  }
  if (root.kind === JsonNodeKind.STRING) {
    // raw 含两端引号，长度要减掉
    return new JsonSummary(root.kind, false, root.raw.length - 2, '');
  }
  return new JsonSummary(root.kind, false, 0, root.raw);
}

/**
 * 去重后的重复键列表（顺序按首次出现）。
 *
 * 不再返回拼好的句子——那句话是文案。页面拿这份列表自己组织语言。
 */
export function uniqueDuplicateKeys(keys: Array<string>): Array<string> {
  const unique: Array<string> = [];
  for (let i: number = 0; i < keys.length; i++) {
    if (unique.indexOf(keys[i]) < 0) {
      unique.push(keys[i]);
    }
  }
  return unique;
}