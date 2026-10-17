/**
 * Epoch 对照表的纯逻辑实现（薄封装时间戳逻辑）。
 *
 * ## 表结构
 *
 * 给定一个「当前毫秒值」，输出常用粒度的当前 epoch 值对照：
 * 秒（10 位）/ 毫秒（13 位）/ 各粒度的换算说明。
 * **确定性**：ms 由调用方传入（可传 Date.now() 或固定值单测），本模块不做时钟读取。
 *
 * @module tools/epoch-table/EpochTable
 */

import { NGFLocalizedText } from '../../core/ToolModel';

/** 一个粒度行 */
export class EpochRow {
  readonly label: NGFLocalizedText;
  readonly value: string;

  constructor(label: NGFLocalizedText, value: string) {
    this.label = label;
    this.value = value;
  }
}

/** 结果 */
export class EpochTableResult {
  readonly rows: Array<EpochRow>;
  /** 当前毫秒值（透传） */
  readonly ms: number;

  constructor(rows: Array<EpochRow>, ms: number) {
    this.rows = rows;
    this.ms = ms;
  }
}

/** 生成对照表 */
export function buildEpochTable(ms: number): EpochTableResult {
  const rows: Array<EpochRow> = [];
  const seconds: number = Math.floor(ms / 1000);
  rows.push(new EpochRow(new NGFLocalizedText('秒（10 位）', 'Seconds (10 digits)'), String(seconds)));
  rows.push(new EpochRow(new NGFLocalizedText('毫秒（13 位）', 'Milliseconds (13 digits)'), String(ms)));
  rows.push(new EpochRow(new NGFLocalizedText('微秒（16 位）', 'Microseconds (16 digits)'), String(ms) + '000'));
  // 常用粒度换算说明
  rows.push(new EpochRow(new NGFLocalizedText('天（自 1970-01-01）', 'Days since 1970-01-01'), String(Math.floor(seconds / 86400))));
  rows.push(new EpochRow(new NGFLocalizedText('小时（自 1970-01-01）', 'Hours since 1970-01-01'), String(Math.floor(seconds / 3600))));
  return new EpochTableResult(rows, ms);
}

/** 从秒值生成对照表（10 位输入场景） */
export function buildEpochTableFromSeconds(seconds: number): EpochTableResult {
  return buildEpochTable(seconds * 1000);
}
