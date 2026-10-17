/**
 * Markdown 表格生成的纯逻辑实现。
 *
 * ## 功能
 *
 * 输入分隔文本（每行一条记录，首行表头，分隔符可配置）转 Markdown 表格。
 * 单元格内的竖线转义。
 *
 * @module tools/md-table-gen/MdTableLogic
 */

/** 失败原因码 */
export enum MdTableFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input'
}

/** 一次失败的原因与文案参数 */
export class MdTableFailure {
  readonly code: MdTableFailureCode;
  readonly args: Array<string>;

  constructor(code: MdTableFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}
/** 结果 */
export class MdTableResult {
  readonly ok: boolean;
  readonly failure: MdTableFailure;
  readonly markdown: string;
  readonly rowCount: number;
  readonly columnCount: number;

  constructor(ok: boolean, failure: MdTableFailure, markdown: string,
    rowCount: number, columnCount: number) {
    this.ok = ok;
    this.failure = failure;
    this.markdown = markdown;
    this.rowCount = rowCount;
    this.columnCount = columnCount;
  }
}

const PIPE: string = String.fromCharCode(124);
const NEWLINE: string = String.fromCharCode(10);

/** 单元格转义：竖线转 &#124; */
function spaceOf(): string {
  return String.fromCharCode(32);
}
function escapeCell(text: string): string {
  return text.split(PIPE).join('&' + String.fromCharCode(35) + '124;');
}
/** 主入口：分隔文本 → Markdown 表格 */
export function generateTable(input: string, delimiter: string): MdTableResult {
  if (input.trim().length === 0) {
    return new MdTableResult(false, new MdTableFailure(MdTableFailureCode.EMPTY_INPUT, []), '', 0, 0);
  }
  const rawLines: Array<string> = input.split(NEWLINE);
  const rows: Array<Array<string>> = [];
  let columnCount: number = 0;
  for (let i = 0; i < rawLines.length; i++) {
    const line: string = rawLines[i].trim();
    if (line.length === 0) {
      continue;
    }
    const cells: Array<string> = line.split(delimiter);
    for (let c = 0; c < cells.length; c++) {
      cells[c] = escapeCell(cells[c].trim());
    }
    if (cells.length > columnCount) {
      columnCount = cells.length;
    }
    rows.push(cells);
  }
  if (rows.length === 0 || columnCount === 0) {
    return new MdTableResult(false, new MdTableFailure(MdTableFailureCode.EMPTY_INPUT, []), '', 0, 0);
  }
  // 表头 + 分隔行 + 数据行（列数不足补空）
  const out: Array<string> = [];
  for (let r = 0; r < rows.length; r++) {
    const cells: Array<string> = rows[r];
    let line: string = PIPE;
    for (let c = 0; c < columnCount; c++) {
      line = line + spaceOf() + (c < cells.length ? cells[c] : '') + spaceOf() + PIPE;
    }
    out.push(line);
    if (r === 0) {
      let sep: string = PIPE;
      for (let c = 0; c < columnCount; c++) {
        sep = sep + ' --- ' + PIPE;
      }
      out.push(sep);
    }
  }
  return new MdTableResult(true, new MdTableFailure(MdTableFailureCode.NONE, []),
    out.join(NEWLINE), rows.length, columnCount);
}
