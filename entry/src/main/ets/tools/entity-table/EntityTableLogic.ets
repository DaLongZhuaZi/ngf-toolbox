/**
 * HTML 实体速查表的纯逻辑实现（本地数据表，与 html-entity 解码工具配对）。
 *
 * ## 数据口径
 *
 * 收录常用命名实体（约 24 条）按用途分组：符号/箭头/数学/引号/版权。
 * 每条「实体 + 字符 + 中文说明」。查询：关键词模糊 + 分类过滤。
 *
 * @module tools/entity-table/EntityTableLogic
 */

import { NGFLocalizedText } from '../../core/ToolModel';
/** 一个条目 */
export class EntityEntry {
  readonly entity: string;
  readonly char: string;
  readonly meaning: NGFLocalizedText;
  readonly category: string;

  constructor(entity: string, char: string, meaning: NGFLocalizedText, category: string) {
    this.entity = entity;
    this.char = char;
    this.meaning = meaning;
    this.category = category;
  }
}

/** 查询结果 */
export class EntityQueryResult {
  readonly entries: Array<EntityEntry>;

  constructor(entries: Array<EntityEntry>) {
    this.entries = entries;
  }
}
const AMP: string = String.fromCharCode(38);
const SEMI: string = String.fromCharCode(59);

function buildTable(): Array<EntityEntry> {
  const list: Array<EntityEntry> = [];
  const add = (entity: string, char: string, meaning: NGFLocalizedText, category: string): void => {
  list.push(new EntityEntry(entity, char, meaning, category));
  };
  // 符号
  add(AMP + 'copy' + SEMI, String.fromCharCode(169), new NGFLocalizedText('版权', 'Copyright'), 'symbol');
  add(AMP + 'reg' + SEMI, String.fromCharCode(174), new NGFLocalizedText('注册商标', 'Registered trademark'), 'symbol');
  add(AMP + 'trade' + SEMI, String.fromCharCode(8482), new NGFLocalizedText('商标', 'Trademark'), 'symbol');
  add(AMP + 'nbsp' + SEMI, String.fromCharCode(160), new NGFLocalizedText('不换行空格', 'Non-breaking space'), 'symbol');
  add(AMP + 'deg' + SEMI, String.fromCharCode(176), new NGFLocalizedText('度数符号', 'Degree sign'), 'symbol');
  add(AMP + 'micro' + SEMI, String.fromCharCode(181), new NGFLocalizedText('微（希腊 mu）', 'Micro (Greek mu)'), 'symbol');
  // 箭头
  add(AMP + 'larr' + SEMI, String.fromCharCode(8592), new NGFLocalizedText('向左箭头', 'Leftwards arrow'), 'arrow');
  add(AMP + 'uarr' + SEMI, String.fromCharCode(8593), new NGFLocalizedText('向上箭头', 'Upwards arrow'), 'arrow');
  add(AMP + 'rarr' + SEMI, String.fromCharCode(8594), new NGFLocalizedText('向右箭头', 'Rightwards arrow'), 'arrow');
  add(AMP + 'darr' + SEMI, String.fromCharCode(8595), new NGFLocalizedText('向下箭头', 'Downwards arrow'), 'arrow');
  add(AMP + 'harr' + SEMI, String.fromCharCode(8596), new NGFLocalizedText('双向箭头', 'Left-right arrow'), 'arrow');
  // 数学
  add(AMP + 'times' + SEMI, String.fromCharCode(215), new NGFLocalizedText('乘号', 'Multiplication sign'), 'math');
  add(AMP + 'divide' + SEMI, String.fromCharCode(247), new NGFLocalizedText('除号', 'Division sign'), 'math');
  add(AMP + 'plusmn' + SEMI, String.fromCharCode(177), new NGFLocalizedText('正负号', 'Plus-minus sign'), 'math');
  add(AMP + 'ne' + SEMI, String.fromCharCode(8800), new NGFLocalizedText('不等于', 'Not equal to'), 'math');
  add(AMP + 'le' + SEMI, String.fromCharCode(8804), new NGFLocalizedText('小于等于', 'Less than or equal to'), 'math');
  add(AMP + 'ge' + SEMI, String.fromCharCode(8805), new NGFLocalizedText('大于等于', 'Greater than or equal to'), 'math');
  add(AMP + 'infin' + SEMI, String.fromCharCode(8734), new NGFLocalizedText('无穷', 'Infinity'), 'math');
  // 引号
  add(AMP + 'quot' + SEMI, String.fromCharCode(34), new NGFLocalizedText('双引号', 'Quotation mark'), 'quote');
  add(AMP + 'apos' + SEMI, String.fromCharCode(39), new NGFLocalizedText('单引号', 'Apostrophe'), 'quote');
  add(AMP + 'ldquo' + SEMI, String.fromCharCode(8220), new NGFLocalizedText('左双引号', 'Left double quote'), 'quote');
  add(AMP + 'rdquo' + SEMI, String.fromCharCode(8221), new NGFLocalizedText('右双引号', 'Right double quote'), 'quote');
  add(AMP + 'lt' + SEMI, String.fromCharCode(60), new NGFLocalizedText('小于号（转义）', 'Less-than (escaped)'), 'quote');
  add(AMP + 'gt' + SEMI, String.fromCharCode(62), new NGFLocalizedText('大于号（转义）', 'Greater-than (escaped)'), 'quote');
  return list;
}
const TABLE: Array<EntityEntry> = buildTable();

/** 全表 */
export function allEntityEntries(): Array<EntityEntry> {
  return TABLE;
}

/** 分类列表 */
export function entityCategories(): Array<string> {
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
export function queryEntities(keyword: string, category: string | null): EntityQueryResult {
  const text: string = keyword.trim().toLowerCase();
  const out: Array<EntityEntry> = [];
  for (let i = 0; i < TABLE.length; i++) {
    const e: EntityEntry = TABLE[i];
    if (category !== null && e.category !== category) {
      continue;
    }
    if (text.length === 0 || e.entity.toLowerCase().indexOf(text) >= 0 ||
      e.meaning.zh.indexOf(keyword.trim()) >= 0 || e.meaning.en.toLowerCase().indexOf(text) >= 0) {
      out.push(e);
    }
  }
  return new EntityQueryResult(out);
}