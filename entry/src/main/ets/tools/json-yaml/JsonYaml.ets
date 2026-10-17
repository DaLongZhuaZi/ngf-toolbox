/**
 * YAML 子集解析的纯逻辑实现（YAML 转 JSON 单向）。
 *
 * ## 支持范围
 *
 * 键值对（标量：字符串/整数/浮点/布尔/null）、一层嵌套对象（缩进两空格）、
 * 行内数组。整行注释（# 开头）被忽略；值中的 # 不做剥离（limitation 写明）。
 *
 * ## 不支持（limitation 会写明）
 *
 * 多行块标量、嵌套数组与对象数组、锚点与引用、多文档分隔符。
 *
 * @module tools/json-yaml/JsonYaml
 */

/** 失败原因码 */
export enum YamlFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  /** 语法错误（带行号） */
  SYNTAX_ERROR = 'syntax_error',
  /** 缩进错误（三层缩进、Tab、无容器） */
  BAD_INDENT = 'bad_indent',
  /** 不支持的多行块标量 */
  UNSUPPORTED_BLOCK = 'unsupported_block',
  /** 多文档 */
  MULTI_DOCUMENT = 'multi_document'
}

/** 一次失败的原因与文案参数 */
export class YamlFailure {
  readonly code: YamlFailureCode;
  readonly args: Array<string>;

  constructor(code: YamlFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 结果 */
export class YamlResult {
  readonly ok: boolean;
  readonly failure: YamlFailure;
  readonly json: string;

  constructor(ok: boolean, failure: YamlFailure, json: string) {
    this.ok = ok;
    this.failure = failure;
    this.json = json;
  }
}

/** null 字面量的哨兵（区别于「解析失败」的 null 返回） */
const NULL_SENTINEL: string = String.fromCharCode(0) + 'null';
const QUOTE: string = String.fromCharCode(34);
const HASH: string = String.fromCharCode(35);
const COLON: string = String.fromCharCode(58);
const COMMA: string = String.fromCharCode(44);
const LBRACK: string = String.fromCharCode(91);
const RBRACK: string = String.fromCharCode(93);
const SPACE: string = String.fromCharCode(32);
const TAB: string = String.fromCharCode(9);
const PIPE: string = String.fromCharCode(124);
const NEWLINE: string = String.fromCharCode(10);

/** 去整行注释（# 开头）；行内 # 不处理 */
function stripFullLineComment(line: string): string {
  if (line.trim().charAt(0) === HASH) {
    return '';
  }
  return line;
}

/** 值解析：字符串/布尔/null/数字/单行数组；解析不了返回 null */
function parseYamlValue(text: string): Object | null {
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
  if (t === 'null' || t === '~') {
    return NULL_SENTINEL;
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
      const v: Object | null = parseYamlValue(parts[i]);
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
  return t;
}

/** 下钻（或创建）子对象 */
function freshChild(node: Record<string, Object | null>, key: string): Record<string, Object | null> {
  const fresh: Record<string, Object | null> = {};
  node[key] = fresh;
  return fresh;
}

/** 主入口：YAML 文本转 JSON 文本 */
export function yamlToJson(input: string): YamlResult {
  if (input.trim().length === 0) {
    return new YamlResult(false, new YamlFailure(YamlFailureCode.EMPTY_INPUT, []), '');
  }
  if (input.indexOf(PIPE) >= 0) {
    return new YamlResult(false, new YamlFailure(YamlFailureCode.UNSUPPORTED_BLOCK, []), '');
  }
  let hasDocSeparator: boolean = false;
  for (let li = 0; li < input.split(NEWLINE).length; li++) {
    if (input.split(NEWLINE)[li].trim() === '---') {
      hasDocSeparator = true;
      break;
    }
  }
  if (hasDocSeparator) {
    return new YamlResult(false, new YamlFailure(YamlFailureCode.MULTI_DOCUMENT, []), '');
  }
  const rawLines: Array<string> = input.split(NEWLINE);
  const root: Record<string, Object | null> = {};
  let current: Record<string, Object | null> | null = null;
  for (let li = 0; li < rawLines.length; li++) {
    const line: string = stripFullLineComment(rawLines[li]);
    if (line.trim().length === 0) {
      continue;
    }
    if (line.charAt(0) === TAB) {
      return new YamlResult(false, new YamlFailure(YamlFailureCode.BAD_INDENT, [String(li + 1)]), '');
    }
    let indent: number = 0;
    while (indent < line.length && line.charAt(indent) === SPACE) {
      indent++;
    }
    const body: string = line.substring(indent);
    const colon: number = body.indexOf(COLON);
    if (colon < 0) {
      return new YamlResult(false, new YamlFailure(YamlFailureCode.SYNTAX_ERROR, [String(li + 1)]), '');
    }
    const key: string = body.substring(0, colon).trim();
    const valuePart: string = body.substring(colon + 1).trim();
    if (indent === 0) {
      if (valuePart.length === 0) {
        current = freshChild(root, key);
      } else {
        const v: Object | null = parseYamlValue(valuePart);
        if (v === null) {
          return new YamlResult(false, new YamlFailure(YamlFailureCode.SYNTAX_ERROR, [String(li + 1)]), '');
        }
        if (v === NULL_SENTINEL) {
          root[key] = null;
        } else {
          root[key] = v as Object;
        }
        current = null;
      }
      continue;
    }
    if (current === null) {
      return new YamlResult(false, new YamlFailure(YamlFailureCode.BAD_INDENT, [String(li + 1)]), '');
    }
    if (indent % 2 !== 0 || indent > 2) {
      return new YamlResult(false, new YamlFailure(YamlFailureCode.BAD_INDENT, [String(li + 1)]), '');
    }
    if (valuePart.length === 0) {
      current = freshChild(current as Record<string, Object | null>, key);
      continue;
    }
    const v2: Object | null = parseYamlValue(valuePart);
    if (v2 === null) {
      return new YamlResult(false, new YamlFailure(YamlFailureCode.SYNTAX_ERROR, [String(li + 1)]), '');
    }
    if (v2 === NULL_SENTINEL) {
      current[key] = null;
    } else {
      current[key] = v2 as Object;
    }
  }
  let json: string = '';
  try {
    json = JSON.stringify(root);
  } catch (e) {
    return new YamlResult(false, new YamlFailure(YamlFailureCode.SYNTAX_ERROR, ['0']), '');
  }
  return new YamlResult(true, new YamlFailure(YamlFailureCode.NONE, []), json);
}