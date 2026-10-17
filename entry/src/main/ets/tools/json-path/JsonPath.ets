/**
 * JSON 点路径取值的纯逻辑实现。
 *
 * ## 路径语法
 *
 * 点分：a.b.c；数组下标：a.list[0].name；根数组：[0].id。
 * **不做**通配符、过滤器、负数下标（limitation 会写明）。
 *
 * ## 为什么手写而不是用 eval
 *
 * eval 既能取值也能**执行**——路径来自用户输入，eval 是注入面。
 * 手写解析器只做「逐段下钻」，安全边界清晰。
 *
 * @module tools/json-path/JsonPath
 */

/** 失败原因码 */
export enum JsonPathFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  EMPTY_PATH = 'empty_path',
  BAD_JSON = 'bad_json',
  /** 路径段在数据中不存在 */
  PATH_NOT_FOUND = 'path_not_found',
  /** 路径语法错误（如 [abc]、a..b） */
  BAD_PATH_SYNTAX = 'bad_path_syntax'
}

/** 一次失败的原因与文案参数 */
export class JsonPathFailure {
  readonly code: JsonPathFailureCode;
  readonly args: Array<string>;

  constructor(code: JsonPathFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 结果 */
export class JsonPathResult {
  readonly ok: boolean;
  readonly failure: JsonPathFailure;
  /** 值的 JSON 文本（对象/数组序列化，标量原样） */
  readonly valueText: string;
  /** 值的 JSON 类型名 */
  readonly type: string;

  constructor(ok: boolean, failure: JsonPathFailure, valueText: string, type: string) {
    this.ok = ok;
    this.failure = failure;
    this.valueText = valueText;
    this.type = type;
  }
}

/** 路径段：键名或数组下标 */
class PathSegment {
  readonly key: string;
  readonly index: number;
  readonly isIndex: boolean;

  constructor(key: string, index: number, isIndex: boolean) {
    this.key = key;
    this.index = index;
    this.isIndex = isIndex;
  }
}

const LBRACKET: string = String.fromCharCode(91);
const RBRACKET: string = String.fromCharCode(93);
const DOT: string = String.fromCharCode(46);

/** 纯数字判断（手写字符循环，不用正则字面量——写入器转义坑） */
function isAllDigits(text: string): boolean {
  if (text.length === 0) {
    return false;
  }
  for (let i = 0; i < text.length; i++) {
    const ch: string = text.charAt(i);
    if (ch < '0' || ch > '9') {
      return false;
    }
  }
  return true;
/** 解析路径为段列表；语法错误返回 null */
}
function parsePathSegments(path: string): Array<PathSegment> | null {
  const segments: Array<PathSegment> = [];
  let i: number = 0;
  let currentKey: string = '';
  const flushKey = (): boolean => {
    if (currentKey.length > 0) {
      segments.push(new PathSegment(currentKey, -1, false));
      currentKey = '';
    }
    return true;
  };
  while (i < path.length) {
    const ch: string = path.charAt(i);
    if (ch === DOT) {
      // 连续点（a..b）报错；但 index 段之后的 . 是正常的（currentKey 被清空）
      if (currentKey.length === 0 && i > 0 && path.charAt(i - 1) === DOT) {
        // a..b 或开头 .
        return null;
      }
      flushKey();
      i++;
      continue;
    }
    if (ch === LBRACKET) {
      flushKey();
      const close: number = path.indexOf(RBRACKET, i);
      if (close < 0) {
        return null;
      }
      const inner: string = path.substring(i + 1, close);
    if (!isAllDigits(inner)) {
        return null;
      }
      segments.push(new PathSegment('', parseInt(inner, 10), true));
      i = close + 1;
      continue;
    }
    currentKey = currentKey + ch;
    i++;
  }
  flushKey();
  if (segments.length === 0) {
    return null;
  }
  return segments;
}

function jsonTypeOf(value: Object): string {
  if (value === null) {
    return 'null';
  }
  if (Array.isArray(value)) {
    return 'array';
  }
  const t: string = typeof value;
  if (t === 'string') {
    return 'string';
  }
  if (t === 'number') {
    return 'number';
  }
  if (t === 'boolean') {
    return 'boolean';
  }
  return 'object';
}

/** 主入口 */
export function queryJsonPath(jsonText: string, path: string): JsonPathResult {
  if (jsonText.trim().length === 0) {
    return new JsonPathResult(false,
      new JsonPathFailure(JsonPathFailureCode.EMPTY_INPUT, []), '', '');
  }
  if (path.trim().length === 0) {
    return new JsonPathResult(false,
      new JsonPathFailure(JsonPathFailureCode.EMPTY_PATH, []), '', '');
  }
  let data: Object | null = null;
  try {
    data = JSON.parse(jsonText) as Object;
  } catch (e) {
    return new JsonPathResult(false,
      new JsonPathFailure(JsonPathFailureCode.BAD_JSON, []), '', '');
  }
  const segments: Array<PathSegment> | null = parsePathSegments(path.trim());
  if (segments === null) {
    return new JsonPathResult(false,
      new JsonPathFailure(JsonPathFailureCode.BAD_PATH_SYNTAX, []), '', '');
  }
  let current: Object = data;
  for (let i = 0; i < segments.length; i++) {
    const seg: PathSegment = segments[i];
    if (current === null || current === undefined) {
      return new JsonPathResult(false,
        new JsonPathFailure(JsonPathFailureCode.PATH_NOT_FOUND, [seg.isIndex ? '[' + seg.index + ']' : seg.key]),
        '', '');
    }
    if (seg.isIndex) {
      if (!Array.isArray(current)) {
        return new JsonPathResult(false,
          new JsonPathFailure(JsonPathFailureCode.PATH_NOT_FOUND, ['[' + seg.index + ']']), '', '');
      }
      const arr: Array<Object> = current as Object as Array<Object>;
      if (seg.index >= arr.length) {
        return new JsonPathResult(false,
          new JsonPathFailure(JsonPathFailureCode.PATH_NOT_FOUND, ['[' + seg.index + ']']), '', '');
      }
      current = arr[seg.index];
    } else {
      const rec: Record<string, Object> = current as Object as Record<string, Object>;
      if (rec[seg.key] === undefined) {
        return new JsonPathResult(false,
          new JsonPathFailure(JsonPathFailureCode.PATH_NOT_FOUND, [seg.key]), '', '');
      }
      current = rec[seg.key];
    }
  }
  const type: string = jsonTypeOf(current);
  let text: string = '';
  if (typeof current === 'string') {
    text = current as string;
  } else if (typeof current === 'number' || typeof current === 'boolean') {
    text = String(current);
  } else {
    try {
      text = JSON.stringify(current);
    } catch (e) {
      text = '';
    }
  }
  return new JsonPathResult(true,
    new JsonPathFailure(JsonPathFailureCode.NONE, []), text, type);
}
