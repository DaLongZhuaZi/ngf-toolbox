/**
 * 存储单位前缀速查表的纯逻辑实现（本地数据表）。
 *
 * ## 数据口径
 *
 * 两套体系对照：二进制前缀 KiB/MiB/GiB（1024 进制，IEC 标准）与
 * 十进制前缀 kB/MB/GB（1000 进制，SI 标准）。磁盘厂商用十进制、
 * 操作系统常用二进制——「500GB 硬盘显示 465GB」就是这个差异。
 *
 * @module tools/unit-table/UnitTableLogic
 */
/** 失败原因码 */
export enum UnitTableFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input'
}

/** 一次失败的原因与文案参数 */
export class UnitTableFailure {
  readonly code: UnitTableFailureCode;
  readonly args: Array<string>;

  constructor(code: UnitTableFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 一条对照 */
export class UnitPair {
  readonly decimal: string;
  readonly binary: string;
  readonly decimalBytes: string;
  readonly binaryBytes: string;

  constructor(decimal: string, binary: string, decimalBytes: string, binaryBytes: string) {
    this.decimal = decimal;
    this.binary = binary;
    this.decimalBytes = decimalBytes;
    this.binaryBytes = binaryBytes;
  }
}

/** 查询结果 */
export class UnitTableResult {
  readonly rows: Array<UnitPair>;

  constructor(rows: Array<UnitPair>) {
    this.rows = rows;
  }
}
/** 全表：KB~PB 两套对照 */
export function unitPairs(): Array<UnitPair> {
  const rows: Array<UnitPair> = [];
  rows.push(new UnitPair('kB', 'KiB', '10^3 = 1,000', '2^10 = 1,024'));
  rows.push(new UnitPair('MB', 'MiB', '10^6 = 1,000,000', '2^20 = 1,048,576'));
  rows.push(new UnitPair('GB', 'GiB', '10^9', '2^30 = 1,073,741,824'));
  rows.push(new UnitPair('TB', 'TiB', '10^12', '2^40'));
  rows.push(new UnitPair('PB', 'PiB', '10^15', '2^50'));
  return rows;
}
/** 字节数在两套体系下的对照（数值精确到两位小数） */
export function bytesInUnits(bytes: number): UnitTableResult {
  const rows: Array<UnitPair> = [];
  const KB: number = Math.pow(10, 3);
  const KIB: number = Math.pow(2, 10);
  const MB: number = Math.pow(10, 6);
  const MIB: number = Math.pow(2, 20);
  const GB: number = Math.pow(10, 9);
  const GIB: number = Math.pow(2, 30);
  const TB: number = Math.pow(10, 12);
  const TIB: number = Math.pow(2, 40);
  const fmt = roundTwo;
  rows.push(new UnitPair('kB', 'KiB', fmt(bytes / KB), fmt(bytes / KIB)));
  rows.push(new UnitPair('MB', 'MiB', fmt(bytes / MB), fmt(bytes / MIB)));
  rows.push(new UnitPair('GB', 'GiB', fmt(bytes / GB), fmt(bytes / GIB)));
  rows.push(new UnitPair('TB', 'TiB', fmt(bytes / TB), fmt(bytes / TIB)));
  return new UnitTableResult(rows);
}

/** 保留两位小数 */
function roundTwo(v: number): string {
  return String(Math.round(v * 100) / 100);
}
