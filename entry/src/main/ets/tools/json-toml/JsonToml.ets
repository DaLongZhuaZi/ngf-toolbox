/**
 * TOML 解析的纯逻辑实现（TOML 转 JSON 单向）。
 *
 * ## 支持范围
 *
 * 基础表 [section]、子表 [a.b]、键值对（字符串/整数/浮点/布尔/单行数组）、
 * 注释（# 开头）、点键（a.b = 1）。
 *
 * ## 不支持（limitation 会写明）
 *
 * 多行字符串（三引号）、内联表、日期时间类型、数组内嵌套表。
 *
 * ## 解析策略
 *
 * 逐行状态机：先去注释（引号外的 #），空行跳过；[ 开头是表头，
 * 其余是键值对（第一个 = 分割）。值按字面形态：带引号是字符串，
 * true/false 是布尔，数字字面量，[ 开头是单行数组。
 *
 * @module tools/json-toml/JsonToml
 */

/** 失败原因码 */
export enum TomlFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  /** 语法错误（带行号） */
  SYNTAX_ERROR = 'syntax_error',
  /** 不支持的多行字符串（三引号） */
  UNSUPPORTED_MULTILINE = 'unsupported_multiline'
}

/** 一次失败的原因与文案参数 */
export class TomlFailure {
  readonly code: TomlFailureCode;
  readonly args: Array<string>;

  constructor(code: TomlFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 结果 */
export class TomlResult {
  readonly ok: boolean;
  readonly failure: TomlFailure;
  readonly json: string;

  constructor(ok: boolean, failure: TomlFailure, json: string) {
    this.ok = ok;
    this.failure = failure;
    this.json = json;
  }
}

const QUOTE: string = String.fromCharCode(34);
const HASH: string = String.fromCharCode(35);
const DOTC: string = String.fromCharCode(46);
const LBRACK: string = String.fromCharCode(91);
const RBRACK: string = String.fromCharCode(93);
const COMMA: string = String.fromCharCode(44);
const EQUALS: string = String.fromCharCode(61);
const TRIPLE: string = QUOTE + QUOTE + QUOTE;

/** 去行注释（引号外的 #） */
function stripComment(line: string): string {
  let inQuote: boolean = false;
  for (let i = 0; i < line.length; i++) {
    const ch: string = line.charAt(i);
    if (ch === QUOTE) {
      inQuote = !inQuote;
    } else if (ch === HASH && !inQuote) {
      return line.substring(0, i);
    }
  }
  return line;
}

/** 值解析：字符串/布尔/数字/单行数组；解析不了返回 null */
function parseTomlValue(text: string): Object | null {
  const t: string = text.trim();
  if (t.length === 0) {
    return null;
  }
  if (t.charAt(0) === QUOTE && t.charAt(t.length - 1) === QUOTE && t.length >= 2) {
    return t.substring(1, t.length - 1);
  }
  if (t === 'true') {
    return true;
  }
  if (t === 'false') {
    return false;
  }
  if (t.charAt(0) === LBRACK && t.charAt(t.length - 1) === RBRACK) {
    const inner: string = t.substring(1, t.length - 1).trim();
    const out: Array<Object> = [];
    if (inner.length === 0) {
      return out;
    }
    let inQuote: boolean = false;
    let buf: string = '';
    const parts: Array<string> = [];
    for (let i = 0; i < inner.length; i++) {
      const ch: string = inner.charAt(i);
      if (ch === QUOTE) {
        inQuote = !inQuote;
        buf = buf + ch;
        continue;
      }
      if (!inQuote && ch === COMMA) {
        parts.push(buf);
        buf = '';
        continue;
      }
      buf = buf + ch;
    }
    parts.push(buf);
    for (let i = 0; i < parts.length; i++) {
      if (parts[i].trim().length === 0) {
        continue;
      }
      const v: Object | null = parseTomlValue(parts[i]);
      if (v === null) {
        return null;
      }
      out.push(v);
    }
    return out;
  }
  const num: number = Number(t);
  if (!isNaN(num)) {
    return num;
  }
  return null;
}

/** 下钻（或创建）子表 */
function drillInto(node: Record<string, Object>, key: string): Record<string, Object> {
  const next: Object = node[key];
  if (next !== undefined && next !== null && typeof next === 'object' && !Array.isArray(next)) {
    return next as Record<string, Object>;
  }
  const fresh: Record<string, Object> = {};
  node[key] = fresh;
  return fresh;
}

/** 主入口：TOML 文本转 JSON 文本 */
export function tomlToJson(input: string): TomlResult {
  if (input.trim().length === 0) {
    return new TomlResult(false, new TomlFailure(TomlFailureCode.EMPTY_INPUT, []), '');
  }
  if (input.indexOf(TRIPLE) >= 0) {
    return new TomlResult(false, new TomlFailure(TomlFailureCode.UNSUPPORTED_MULTILINE, []), '');
  }
  const lines: Array<string> = input.split(String.fromCharCode(10));
  const root: Record<string, Object> = {};
  let current: Record<string, Object> = root;
  for (let li = 0; li < lines.length; li++) {
    const line: string = stripComment(lines[li]).trim();
    if (line.length === 0) {
      continue;
    }
    if (line.charAt(0) === LBRACK) {
      const close: number = line.indexOf(RBRACK);
      if (close < 0) {
        return new TomlResult(false,
          new TomlFailure(TomlFailureCode.SYNTAX_ERROR, [String(li + 1)]), '');
      }
      const path: string = line.substring(1, close).trim();
      const parts: Array<string> = path.split(DOTC);
      let node: Record<string, Object> = root;
      for (let i = 0; i < parts.length; i++) {
        node = drillInto(node, parts[i].trim());
      }
      current = node;
      continue;
    }
    const eq: number = line.indexOf(EQUALS);
    if (eq < 0) {
      return new TomlResult(false,
        new TomlFailure(TomlFailureCode.SYNTAX_ERROR, [String(li + 1)]), '');
    }
    const keyPart: string = line.substring(0, eq).trim();
    const valuePart: string = line.substring(eq + 1).trim();
    const value: Object | null = parseTomlValue(valuePart);
    if (value === null) {
      return new TomlResult(false,
        new TomlFailure(TomlFailureCode.SYNTAX_ERROR, [String(li + 1)]), '');
    }
    const keyParts: Array<string> = keyPart.split(DOTC);
    let node: Record<string, Object> = current;
    for (let i = 0; i < keyParts.length - 1; i++) {
      node = drillInto(node, keyParts[i].trim());
    }
    node[keyParts[keyParts.length - 1].trim()] = value;
  }
  let json: string = '';
  try {
    json = JSON.stringify(root);
  } catch (e) {
    return new TomlResult(false, new TomlFailure(TomlFailureCode.SYNTAX_ERROR, ['0']), '');
  }
  return new TomlResult(true, new TomlFailure(TomlFailureCode.NONE, []), json);
}