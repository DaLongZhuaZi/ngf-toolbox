/**
 * JSON 转接口文档的纯逻辑实现。
 *
 * ## 输出形态
 *
 * Markdown 表格：路径、类型、说明（说明列留空，用户补充）。数组取第一个元素
 * 作为样例下钻（路径带 [0]）；空数组只标注类型。嵌套深度上限 4 层。
 *
 * @module tools/json2doc/Json2DocLogic
 */

/** 失败原因码 */
export enum Json2DocFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  BAD_JSON = 'bad_json'
}

/** 一次失败的原因与文案参数 */
export class Json2DocFailure {
  readonly code: Json2DocFailureCode;
  readonly args: Array<string>;

  constructor(code: Json2DocFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 结果 */
export class Json2DocResult {
  readonly ok: boolean;
  readonly failure: Json2DocFailure;
  readonly markdown: string;
  /** 字段数 */
  readonly fieldCount: number;

  constructor(ok: boolean, failure: Json2DocFailure, markdown: string, fieldCount: number) {
    this.ok = ok;
    this.failure = failure;
    this.markdown = markdown;
    this.fieldCount = fieldCount;
  }
}

const MAX_DEPTH: number = 4;
const NEWLINE: string = String.fromCharCode(10);

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

/** 递归收集字段行 */
function collectRows(prefix: string, value: Object, depth: number, rows: Array<string>): void {
  const type: string = jsonTypeOf(value);
  rows.push(prefix + ' | ' + type + ' |  |');
  if (depth >= MAX_DEPTH) {
    return;
  }
  if (type === 'object') {
    const rec: Record<string, Object> = value as Record<string, Object>;
    const keys: Array<string> = Object.keys(rec);
    for (let i = 0; i < keys.length; i++) {
      const childPath: string = prefix.length === 0 ? keys[i] : prefix + '.' + keys[i];
      collectRows(childPath, rec[keys[i]], depth + 1, rows);
    }
  } else if (type === 'array') {
    const arr: Array<Object> = value as Array<Object>;
    if (arr.length > 0) {
      collectRows(prefix + '[0]', arr[0], depth + 1, rows);
    }
  }
}

/** 主入口 */
export function jsonToDoc(input: string, english: boolean): Json2DocResult {
  if (input.trim().length === 0) {
    return new Json2DocResult(false, new Json2DocFailure(Json2DocFailureCode.EMPTY_INPUT, []), '', 0);
  }
  let data: Object | null = null;
  try {
    data = JSON.parse(input) as Object;
  } catch (e) {
    return new Json2DocResult(false, new Json2DocFailure(Json2DocFailureCode.BAD_JSON, []), '', 0);
  }
  const rows: Array<string> = [];
  const rootType: string = jsonTypeOf(data);
  if (rootType === 'object') {
    const rec: Record<string, Object> = data as Record<string, Object>;
    const keys: Array<string> = Object.keys(rec);
    for (let i = 0; i < keys.length; i++) {
      collectRows(keys[i], rec[keys[i]] as Object, 1, rows);
    }
  } else {
    collectRows('', data as Object, 0, rows);
  }
  const header: string = english ? 'Path | Type | Description' : '路径 | 类型 | 说明'; // i18n-corpus-data
  const sep: string = '--- | --- | ---';
  const markdown: string = header + NEWLINE + sep + NEWLINE + rows.join(NEWLINE);
  return new Json2DocResult(true, new Json2DocFailure(Json2DocFailureCode.NONE, []), markdown, rows.length);
}