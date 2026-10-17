/**
 * SQL 格式化的纯逻辑实现。
 *
 * ## 规则
 *
 * 关键字大写（SELECT/FROM/WHERE/AND/OR/JOIN/ON/ORDER/GROUP/LIMIT/INSERT/UPDATE/
 * DELETE/VALUES/SET/AS/IN/NOT/NULL/LIKE/BETWEEN）；主子句（SELECT/FROM/WHERE/
 * ORDER BY/GROUP BY/LIMIT/JOIN）前换行，条件连接词（AND/OR）换行加两空格缩进；
 * 字符串字面量（单引号）内部不处理。
 *
 * ## 不做（limitation 会写明）
 *
 * 不解析语法树、不校验 SQL 合法性——只是文本级重排；方言差异（窗口函数、CTE）
 * 不特殊处理。
 *
 * @module tools/sql-format/SqlFormat
 */

/** 失败原因码 */
export enum SqlFormatFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  /** 引号未闭合 */
  UNCLOSED_QUOTE = 'unclosed_quote'
}

/** 一次失败的原因与文案参数 */
export class SqlFormatFailure {
  readonly code: SqlFormatFailureCode;
  readonly args: Array<string>;

  constructor(code: SqlFormatFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 结果 */
export class SqlFormatResult {
  readonly ok: boolean;
  readonly failure: SqlFormatFailure;
  readonly formatted: string;

  constructor(ok: boolean, failure: SqlFormatFailure, formatted: string) {
    this.ok = ok;
    this.failure = failure;
    this.formatted = formatted;
  }
}

const SPACE: string = String.fromCharCode(32);
const NEWLINE: string = String.fromCharCode(10);
const SQUOTE: string = String.fromCharCode(39);
const COMMA: string = String.fromCharCode(44);
const INDENT: string = SPACE + SPACE;

/** 主子句（前面换行、顶格） */
const MAIN_CLAUSES: Array<string> = [
  'SELECT', 'FROM', 'WHERE', 'ORDER BY', 'GROUP BY', 'HAVING', 'LIMIT',
  'INSERT INTO', 'VALUES', 'UPDATE', 'SET', 'DELETE FROM', 'LEFT JOIN',
  'RIGHT JOIN', 'INNER JOIN', 'JOIN', 'ON'
];

/** 条件连接词（换行 + 缩进） */
const CONNECTORS: Array<string> = ['AND', 'OR'];

/** 大写关键字表（词边界整词替换） */
const KEYWORDS: Array<string> = [
  'SELECT', 'DISTINCT', 'FROM', 'WHERE', 'AND', 'OR', 'NOT', 'NULL', 'IS',
  'IN', 'LIKE', 'BETWEEN', 'AS', 'JOIN', 'LEFT', 'RIGHT', 'INNER', 'OUTER',
  'ON', 'ORDER', 'GROUP', 'BY', 'HAVING', 'LIMIT', 'OFFSET', 'INSERT',
  'INTO', 'VALUES', 'UPDATE', 'SET', 'DELETE', 'COUNT', 'SUM', 'AVG',
  'MIN', 'MAX', 'DESC', 'ASC'
];

/** 词边界大写替换（跳过引号内） */
function uppercaseKeywords(text: string): string {
  let out: string = text;
  for (let i = 0; i < KEYWORDS.length; i++) {
    const kw: string = KEYWORDS[i];
    // 大写与小写两种形态做整词替换（词边界用前后非字母判断）
    out = replaceWord(out, kw.toLowerCase(), kw);
    out = replaceWord(out, kw, kw);
  }
  return out;
}

function isWordChar(ch: string): boolean {
  if (ch >= 'a' && ch <= 'z') {
    return true;
  }
  if (ch >= 'A' && ch <= 'Z') {
    return true;
  }
  if (ch >= '0' && ch <= '9') {
    return true;
  }
  return ch === '_';
}

/** 整词替换（前后不是字母数字下划线才算命中） */
function replaceWord(text: string, from: string, to: string): string {
  let result: string = '';
  let i: number = 0;
  while (i < text.length) {
    if (text.charAt(i) === SQUOTE) {
      // 引号串原样跳过
      let j: number = i + 1;
      let closed: boolean = false;
      while (j < text.length) {
        if (text.charAt(j) === SQUOTE) {
          closed = true;
          break;
        }
        j++;
      }
      if (!closed) {
        return text.substring(i);
      }
      result = result + text.substring(i, j + 1);
      i = j + 1;
      continue;
    }
    const segment: string = text.substring(i, i + from.length).toLowerCase();
    const matches: boolean = segment === from &&
      (i === 0 || !isWordChar(text.charAt(i - 1))) &&
      (i + from.length >= text.length || !isWordChar(text.charAt(i + from.length)));
    if (matches) {
      result = result + to;
      i = i + from.length;
      continue;
    }
    result = result + text.charAt(i);
    i++;
  }
  return result;
}

/** 主入口 */
/** 只去右侧空白（保留连接词行的左缩进） */
function trimEndOnly(text: string): string {
  let end: number = text.length;
  while (end > 0 && (text.charAt(end - 1) === SPACE || text.charAt(end - 1) === String.fromCharCode(9))) {
    end--;
  }
  return text.substring(0, end);
}

export function formatSql(input: string): SqlFormatResult {
  if (input.trim().length === 0) {
    return new SqlFormatResult(false, new SqlFormatFailure(SqlFormatFailureCode.EMPTY_INPUT, []), '');
  }
  // 引号闭合校验
  let quoteCount: number = 0;
  for (let i = 0; i < input.length; i++) {
    if (input.charAt(i) === SQUOTE) {
      quoteCount++;
    }
  }
  if (quoteCount % 2 !== 0) {
    return new SqlFormatResult(false, new SqlFormatFailure(SqlFormatFailureCode.UNCLOSED_QUOTE, []), '');
  }
  const uppered: string = uppercaseKeywords(input);
  // 按 token 换行：扫描主子句与连接词
  const tokens: Array<string> = uppered.split(/\s+/);
  const outLines: Array<string> = [];
  let buf: string = '';
  let i: number = 0;
  while (i < tokens.length) {
    const tok: string = tokens[i];
    let matched: string = '';
    // 先匹配两词主子句
    if (i + 1 < tokens.length) {
      const pair: string = tok + SPACE + tokens[i + 1];
      for (let k = 0; k < MAIN_CLAUSES.length; k++) {
        if (MAIN_CLAUSES[k] === pair) {
          matched = pair;
          break;
        }
      }
    }
    if (matched.length > 0) {
      if (buf.trim().length > 0) {
        outLines.push(trimEndOnly(buf));
      }
      buf = matched;
      i = i + 2;
      continue;
    }
    let isMain: boolean = false;
    for (let k = 0; k < MAIN_CLAUSES.length; k++) {
      if (MAIN_CLAUSES[k] === tok) {
        isMain = true;
        break;
      }
    }
    let isConn: boolean = false;
    for (let k = 0; k < CONNECTORS.length; k++) {
      if (CONNECTORS[k] === tok) {
        isConn = true;
        break;
      }
    }
    if (isMain) {
      if (buf.trim().length > 0) {
        outLines.push(trimEndOnly(buf));
      }
      buf = tok;
      i++;
      continue;
    }
    if (isConn) {
      if (buf.trim().length > 0) {
        outLines.push(trimEndOnly(buf));
      }
      buf = INDENT + tok;
      i++;
      continue;
    }
    buf = buf + SPACE + tok;
    i++;
  }
  if (buf.trim().length > 0) {
    outLines.push(trimEndOnly(buf));
  }
  return new SqlFormatResult(true, new SqlFormatFailure(SqlFormatFailureCode.NONE, []),
    outLines.join(NEWLINE));
}