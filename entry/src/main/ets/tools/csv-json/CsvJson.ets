/**
 * CSV ↔ JSON 互转的纯逻辑实现。
 *
 * ## CSV 解析按 RFC 4180
 *
 * 1. 首行是表头；2. 引号字段内的逗号/换行/双引号不拆分；3. 字段内的双引号
 * 写成两个双引号（"" → "）。这三条是 CSV 的全部难点，手写状态机最可靠。
 *
 * ## 值类型推断
 *
 * JSON 侧要求类型：全数字 → number（不丢精度的写法：长度 > 15 位保留为 string），
 * true/false → boolean，空串 → null，其余 → string。推断**只发生在 CSV→JSON 方向**；
 * JSON→CSV 时全部转字符串（CSV 没有类型）。
 *
 * ## 不支持的（limitation 会写明）
 *
 * 引号内换行支持，但**多行记录**（一条记录跨多物理行）解析后统计按行展示会有歧义；
 * 不做分隔符配置（只认逗号）、不做编码猜测（输入必须是字符串）。
 *
 * @module tools/csv-json/CsvJson
 */

/** 失败原因码 */
export enum CsvJsonFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  /** 只有表头没有数据行 */
  NO_DATA_ROWS = 'no_data_rows',
  /** 某行字段数与表头不一致 */
  COLUMN_MISMATCH = 'column_mismatch',
  /** JSON 不是对象数组 */
  NOT_OBJECT_ARRAY = 'not_object_array',
  /** JSON 解析失败（透传行列信息） */
  BAD_JSON = 'bad_json',
  /** 对象键不一致（第一行的键集合与其余行不同） */
  INCONSISTENT_KEYS = 'inconsistent_keys'
}

/** 一次失败的原因与文案参数 */
export class CsvJsonFailure {
  readonly code: CsvJsonFailureCode;
  readonly args: Array<string>;

  constructor(code: CsvJsonFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** CSV → JSON 的结果 */
export class CsvToJsonResult {
  readonly ok: boolean;
  readonly failure: CsvJsonFailure;
  /** JSON 文本（两空格缩进） */
  readonly json: string;
  readonly rowCount: number;
  readonly columnCount: number;

  constructor(ok: boolean, failure: CsvJsonFailure, json: string,
    rowCount: number, columnCount: number) {
    this.ok = ok;
    this.failure = failure;
    this.json = json;
    this.rowCount = rowCount;
    this.columnCount = columnCount;
  }
}

/** JSON → CSV 的结果 */
export class JsonToCsvResult {
  readonly ok: boolean;
  readonly failure: CsvJsonFailure;
  readonly csv: string;
  readonly rowCount: number;
  readonly columnCount: number;

  constructor(ok: boolean, failure: CsvJsonFailure, csv: string,
    rowCount: number, columnCount: number) {
    this.ok = ok;
    this.failure = failure;
    this.csv = csv;
    this.rowCount = rowCount;
    this.columnCount = columnCount;
  }
}

function comma(): string {
  return String.fromCharCode(44);
}

function quote(): string {
  return String.fromCharCode(34);
}

function newline(): string {
  return String.fromCharCode(10);
}

/**
 * 按 RFC 4180 解析一行（也可能是多物理行——引号内换行会吞行）。
 * 返回字段数组与**消耗的行数**。
 */
function parseCsvRecord(lines: Array<string>, start: number): [Array<string>, number] {
  const fields: Array<string> = [];
  let current: string = '';
  let inQuotes: boolean = false;
  let consumed: number = 0;
  let i: number = start;
  while (i < lines.length) {
    const line: string = lines[i];
    let j: number = 0;
    while (j < line.length) {
      const ch: string = line.charAt(j);
      if (inQuotes) {
        if (ch === quote()) {
          if (j + 1 < line.length && line.charAt(j + 1) === quote()) {
            current = current + quote();
            j = j + 2;
            continue;
          }
          inQuotes = false;
          j++;
          continue;
        }
        current = current + ch;
        j++;
        continue;
      }
      if (ch === quote() && current.length === 0) {
        inQuotes = true;
        j++;
        continue;
      }
      if (ch === comma()) {
        fields.push(current);
        current = '';
        j++;
        continue;
      }
      current = current + ch;
      j++;
    }
    consumed++;
    i++;
    if (!inQuotes) {
      break;
    }
    // 引号未闭合：记录跨行，继续吞下一行，字段内补换行
    current = current + newline();
  }
  fields.push(current);
  return [fields, consumed];
}

/** 判断是否是合法数字字面量（手写字符循环，不用正则字面量） */
function isNumericLiteral(raw: string): boolean {
  let i: number = 0;
  if (i < raw.length && raw.charAt(i) === '-') {
    i++;
  }
  let intDigits: number = 0;
  while (i < raw.length && raw.charAt(i) >= '0' && raw.charAt(i) <= '9') {
    i++;
    intDigits++;
  }
  if (intDigits === 0) {
    return false;
  }
  if (i < raw.length && raw.charAt(i) === String.fromCharCode(46)) {
    i++;
    let fracDigits: number = 0;
    while (i < raw.length && raw.charAt(i) >= '0' && raw.charAt(i) <= '9') {
      i++;
      fracDigits++;
    }
    if (fracDigits === 0) {
      return false;
    }
  }
  if (i < raw.length && (raw.charAt(i) === 'e' || raw.charAt(i) === 'E')) {
    i++;
    if (i < raw.length && (raw.charAt(i) === '+' || raw.charAt(i) === '-')) {
      i++;
    }
    let expDigits: number = 0;
    while (i < raw.length && raw.charAt(i) >= '0' && raw.charAt(i) <= '9') {
      i++;
      expDigits++;
    }
    if (expDigits === 0) {
      return false;
    }
  }
  return i === raw.length;
}

/** 值类型推断（见文件头说明） */
function inferValue(raw: string): string {
  if (raw.length === 0) {
    return 'null';
  }
  if (raw === 'true') {
    return 'true';
  }
  if (raw === 'false') {
    return 'false';
  }
  // 数字：长度 ≤ 15 才当 number（避免大整数丢精度）。
  // 不用正则字面量——模板写入器会把 \\. 写成字面双反斜杠（第 73 轮起反复踩），
  // 改成手写字符循环，两个运行器行为一致。
  if (raw.length <= 15 && isNumericLiteral(raw)) {
    return raw;
  }
  // JSON 字符串转义：" 要写成 \\"（反斜杠+引号），不能用 CSV 的 "" 双写。
  // 反斜杠字符用 fromCharCode(92) 表达（写入器写不进字面反斜杠）。
  const escaped: string = raw.split(String.fromCharCode(92)).join(String.fromCharCode(92) + String.fromCharCode(92))
    .split(quote()).join(String.fromCharCode(92) + quote());
  return quote() + escaped + quote();
}

function needsQuoting(field: string): boolean {
  if (field.indexOf(comma()) >= 0 || field.indexOf(quote()) >= 0 || field.indexOf(newline()) >= 0) {
    return true;
  }
  return field.length > 0 && field.charAt(0) === String.fromCharCode(32);
}

function csvEscape(field: string): string {
  if (needsQuoting(field)) {
    return quote() + field.split(quote()).join(quote() + quote()) + quote();
  }
  return field;
}

/** JSON 对象序列化成一行 CSV 字段（按键顺序） */
function objectToFields(keys: Array<string>, obj: Map<string, string>): Array<string> {
  const out: Array<string> = [];
  for (let i = 0; i < keys.length; i++) {
    const v: string = obj.has(keys[i]) ? (obj.get(keys[i]) as string) : '';
    out.push(csvEscape(v));
  }
  return out;
}

/** CSV → JSON */
export function csvToJson(input: string): CsvToJsonResult {
  if (input.trim().length === 0) {
    return new CsvToJsonResult(false,
      new CsvJsonFailure(CsvJsonFailureCode.EMPTY_INPUT, []), '', 0, 0);
  }
  const normalized: string = input.split(String.fromCharCode(13) + String.fromCharCode(10)).join(newline());
  const physicalLines: Array<string> = normalized.split(newline());
  const header: Array<string> = [];
  const consumed0: [Array<string>, number] = parseCsvRecord(physicalLines, 0);
  for (let i = 0; i < consumed0[0].length; i++) {
    header.push(consumed0[0][i].trim());
  }
  const headerLines: number = consumed0[1];
  if (header.length === 0) {
    return new CsvToJsonResult(false,
      new CsvJsonFailure(CsvJsonFailureCode.NO_DATA_ROWS, []), '', 0, 0);
  }
  const objects: Array<string> = [];
  let rowCount: number = 0;
  let lineIdx: number = headerLines;
  while (lineIdx < physicalLines.length) {
    if (physicalLines[lineIdx].trim().length === 0) {
      lineIdx++;
      continue;
    }
    const rec: [Array<string>, number] = parseCsvRecord(physicalLines, lineIdx);
    const fields: Array<string> = rec[0];
    if (fields.length !== header.length) {
      return new CsvToJsonResult(false,
        new CsvJsonFailure(CsvJsonFailureCode.COLUMN_MISMATCH, [String(rowCount + 2),
          String(fields.length), String(header.length)]), '', 0, 0);
    }
    const props: Array<string> = [];
    for (let c = 0; c < header.length; c++) {
      const key: string = header[c];
      const value: string = inferValue(fields[c]);
      props.push(quote() + key.split(quote()).join(quote() + quote()) + quote() + ': ' + value);
    }
    objects.push('    {' + props.join(', ') + '}');
    rowCount++;
    lineIdx = lineIdx + rec[1];
  }
  if (rowCount === 0) {
    return new CsvToJsonResult(false,
      new CsvJsonFailure(CsvJsonFailureCode.NO_DATA_ROWS, []), '', 0, header.length);
  }
  const json: string = '[' + newline() + objects.join(',' + newline()) + newline() + ']';
  return new CsvToJsonResult(true,
    new CsvJsonFailure(CsvJsonFailureCode.NONE, []), json, rowCount, header.length);
}

/** JSON → CSV。输入必须是对象数组且所有对象的键集合一致（顺序以第一行为准） */
export function jsonToCsv(input: string): JsonToCsvResult {
  if (input.trim().length === 0) {
    return new JsonToCsvResult(false,
      new CsvJsonFailure(CsvJsonFailureCode.EMPTY_INPUT, []), '', 0, 0);
  }
  let parsed: Record<string, Object> | null = null;
  try {
    const t: string = input.trim();
    parsed = JSON.parse(t) as Record<string, Object>;
  } catch (e) {
    return new JsonToCsvResult(false,
      new CsvJsonFailure(CsvJsonFailureCode.BAD_JSON, []), '', 0, 0);
  }
  if (!Array.isArray(parsed)) {
    return new JsonToCsvResult(false,
      new CsvJsonFailure(CsvJsonFailureCode.NOT_OBJECT_ARRAY, []), '', 0, 0);
  }
  const arr: Array<Object> = parsed as Object as Array<Object>;
  if (arr.length === 0) {
    return new JsonToCsvResult(false,
      new CsvJsonFailure(CsvJsonFailureCode.NO_DATA_ROWS, []), '', 0, 0);
  }
  // 首元素必须是对象：[1,2] 这种纯值数组在这里报 NOT_OBJECT_ARRAY，
  // 而不是往下走 Object.keys(1) 得空键集、错报 NO_DATA_ROWS（第一版就这么错的）。
  if (arr[0] === null || typeof arr[0] !== 'object') {
    return new JsonToCsvResult(false,
      new CsvJsonFailure(CsvJsonFailureCode.NOT_OBJECT_ARRAY, []), '', 0, 0);
  }
  // 键集合以第一行为准
  const first: Map<string, string> = Object.keys(arr[0]) === undefined ? new Map<string, string>() : new Map<string, string>();
  const keys: Array<string> = [];
  const firstObj: Record<string, Object> = arr[0] as Record<string, Object>;
  for (const k of Object.keys(firstObj)) {
    keys.push(k);
    const v: Object = firstObj[k];
    first.set(k, v === null || v === undefined ? '' : String(v));
  }
  if (keys.length === 0) {
    return new JsonToCsvResult(false,
      new CsvJsonFailure(CsvJsonFailureCode.NO_DATA_ROWS, []), '', 0, 0);
  }
  const rows: Array<Array<string>> = [];
  const header: Array<string> = [];
  for (let i = 0; i < keys.length; i++) {
    header.push(csvEscape(keys[i]));
  }
  rows.push(header);
  for (let r = 0; r < arr.length; r++) {
    const obj: Record<string, Object> = arr[r] as Record<string, Object>;
    const values: Map<string, string> = new Map<string, string>();
    for (const k of Object.keys(obj)) {
      const v: Object = obj[k];
      values.set(k, v === null || v === undefined ? '' : String(v));
    }
    for (let c = 0; c < keys.length; c++) {
      if (!values.has(keys[c])) {
        return new JsonToCsvResult(false,
          new CsvJsonFailure(CsvJsonFailureCode.INCONSISTENT_KEYS, [String(r + 1), keys[c]]), '', 0, 0);
      }
    }
    rows.push(objectToFields(keys, values));
  }
  const csv: string = rows.map((r2: Array<string>): string => r2.join(comma())).join(newline());
  return new JsonToCsvResult(true,
    new CsvJsonFailure(CsvJsonFailureCode.NONE, []), csv, arr.length, keys.length);
}
