/**
 * Cron 表达式速查表的纯逻辑实现（本地数据表，与 cron-parser 配对）。
 *
 * ## 数据口径
 *
 * 收录高频 cron 表达式（约 22 条）按频率分组：每分钟/每小时/每天/每周/每月/
 * 每年/特殊。每条「表达式 + 中文含义」。查询：关键词模糊 + 分类过滤。
 *
 * @module tools/cron-cheatsheet/CronCheatsheetLogic
 */

import { NGFLocalizedText } from '../../core/ToolModel';

/** 一个条目 */
export class CronEntry {
  readonly expr: string;
  readonly meaning: NGFLocalizedText;
  readonly category: string;

  constructor(expr: string, meaning: NGFLocalizedText, category: string) {
    this.expr = expr;
    this.meaning = meaning;
    this.category = category;
  }
}

/** 查询结果 */
export class CronQueryResult {
  readonly entries: Array<CronEntry>;

  constructor(entries: Array<CronEntry>) {
    this.entries = entries;
  }
}

function buildTable(): Array<CronEntry> {
  const list: Array<CronEntry> = [];
  const add = (expr: string, meaning: NGFLocalizedText, category: string): void => {
  list.push(new CronEntry(expr, meaning, category));
  };
  // 每分钟/每小时
  add('* * * * *', new NGFLocalizedText('每分钟', 'Every minute'), 'minute');
  add('*/5 * * * *', new NGFLocalizedText('每 5 分钟', 'Every 5 minutes'), 'minute');
  add('*/15 * * * *', new NGFLocalizedText('每 15 分钟', 'Every 15 minutes'), 'minute');
  add('0 * * * *', new NGFLocalizedText('每小时整点', 'At the top of every hour'), 'hour');
  add('30 * * * *', new NGFLocalizedText('每小时第 30 分', 'At 30 past every hour'), 'hour');
  add('0 0,12 * * *', new NGFLocalizedText('每天 0 点与 12 点', 'At midnight and noon daily'), 'hour');
  // 每天
  add('0 2 * * *', new NGFLocalizedText('每天凌晨 2 点', 'Daily at 02:00'), 'day');
  add('0 9 * * 1-5', new NGFLocalizedText('工作日每天 9 点', 'Weekdays at 09:00'), 'day');
  add('30 8 * * *', new NGFLocalizedText('每天 8:30', 'Daily at 08:30'), 'day');
  add('0 18 * * *', new NGFLocalizedText('每天 18 点', 'Daily at 18:00'), 'day');
  // 每周/每月/每年
  add('0 9 * * 1', new NGFLocalizedText('每周一 9 点', 'Mondays at 09:00'), 'week');
  add('0 9 * * 6,0', new NGFLocalizedText('每周六日 9 点', 'Weekends at 09:00'), 'week');
  add('0 0 1 * *', new NGFLocalizedText('每月 1 日零点', 'First day of the month at midnight'), 'month');
  add('0 0 1 1 *', new NGFLocalizedText('每年 1 月 1 日', 'Every January 1st at midnight'), 'year');
  add('0 0 1 3,6,9,12 *', new NGFLocalizedText('每季度首月 1 日', 'First day of each quarter month'), 'year');
  // 特殊
  add('@reboot', new NGFLocalizedText('重启时执行', 'At startup'), 'special');
  add('@hourly', new NGFLocalizedText('每小时（等价 0 * * * *）', 'Hourly (same as 0 * * * *)'), 'special');
  add('@daily', new NGFLocalizedText('每天零点（等价 0 0 * * *）', 'Daily at midnight (same as 0 0 * * *)'), 'special');
  add('@weekly', new NGFLocalizedText('每周（等价 0 0 * * 0）', 'Weekly (same as 0 0 * * 0)'), 'special');
  add('@monthly', new NGFLocalizedText('每月（等价 0 0 1 * *）', 'Monthly (same as 0 0 1 * *)'), 'special');
  add('@yearly', new NGFLocalizedText('每年（等价 0 0 1 1 *）', 'Yearly (same as 0 0 1 1 *)'), 'special');
  return list;
}

const TABLE: Array<CronEntry> = buildTable();

/** 全表 */
export function allCronEntries(): Array<CronEntry> {
  return TABLE;
}

/** 分类列表 */
export function cronCategories(): Array<string> {
  const seen: Set<string> = new Set<string>();
  const out: Array<string> = [];
  for (let i = 0; i < TABLE.length; i++) {
    if (!seen.has(TABLE[i].category)) {
      seen.add(TABLE[i].category);
      out.push(TABLE[i].category);
    }
  }
  return out;
}

/** 查询 */
export function queryCron(keyword: string, category: string | null): CronQueryResult {
  const text: string = keyword.trim().toLowerCase();
  const out: Array<CronEntry> = [];
  for (let i = 0; i < TABLE.length; i++) {
    const e: CronEntry = TABLE[i];
    if (category !== null && e.category !== category) {
      continue;
    }
    if (text.length === 0 || e.expr.toLowerCase().indexOf(text) >= 0 ||
      e.meaning.zh.indexOf(keyword.trim()) >= 0 || e.meaning.en.toLowerCase().indexOf(text) >= 0) {
      out.push(e);
    }
  }
  return new CronQueryResult(out);
}