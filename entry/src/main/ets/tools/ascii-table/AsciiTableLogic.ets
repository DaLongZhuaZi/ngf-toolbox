/**
 * ASCII 对照表的纯逻辑实现（本地数据表）。
 *
 * ## 数据口径
 *
 * 收录常用 ASCII：控制字符（0-31 的代表 + DEL）与可打印字符（32-126）——
 * 每条「十进制 + 十六进制 + 字符 + 说明」。查询：数字/名称模糊 + 分类过滤。
 *
 * @module tools/ascii-table/AsciiTableLogic
 */

import { NGFLocalizedText } from '../../core/ToolModel';
/** 一个条目 */
export class AsciiEntry {
  readonly decimal: number;
  readonly hex: string;
  readonly char: string;
  readonly meaning: NGFLocalizedText;
  readonly category: string;

  constructor(decimal: number, hex: string, char: string, meaning: NGFLocalizedText, category: string) {
    this.decimal = decimal;
    this.hex = hex;
    this.char = char;
    this.meaning = meaning;
    this.category = category;
  }
}

/** 查询结果 */
export class AsciiQueryResult {
  readonly entries: Array<AsciiEntry>;

  constructor(entries: Array<AsciiEntry>) {
    this.entries = entries;
  }
}
const SLASH: string = String.fromCharCode(47);
const BACKSLASH: string = String.fromCharCode(92);
const SPACEC: string = String.fromCharCode(32);

function buildTable(): Array<AsciiEntry> {
  const list: Array<AsciiEntry> = [];
  const add = (decimal: number, char: string, meaning: NGFLocalizedText, category: string): void => {
    list.push(new AsciiEntry(decimal, '0x' + decimal.toString(16).toUpperCase(), char, meaning, category));
  };
  // 控制字符（代表性）
  add(0, String.fromCharCode(0), new NGFLocalizedText('NUL 空字符', 'NUL null'), 'ctrl');
  add(7, String.fromCharCode(7), new NGFLocalizedText('BEL 响铃', 'BEL bell'), 'ctrl');
  add(8, String.fromCharCode(8), new NGFLocalizedText('BS 退格', 'BS backspace'), 'ctrl');
  add(9, String.fromCharCode(9), new NGFLocalizedText('TAB 制表', 'TAB horizontal tab'), 'ctrl');
  add(10, String.fromCharCode(10), new NGFLocalizedText('LF 换行', 'LF line feed'), 'ctrl');
  add(13, String.fromCharCode(13), new NGFLocalizedText('CR 回车', 'CR carriage return'), 'ctrl');
  add(27, String.fromCharCode(27), new NGFLocalizedText('ESC 退出', 'ESC escape'), 'ctrl');
  add(127, String.fromCharCode(127), new NGFLocalizedText('DEL 删除', 'DEL delete'), 'ctrl');
  // 可打印
  add(32, SPACEC, new NGFLocalizedText('空格', 'Space'), 'print');
  add(33, '!', new NGFLocalizedText('感叹号', 'Exclamation mark'), 'print');
  add(34, String.fromCharCode(34), new NGFLocalizedText('双引号', 'Quotation mark'), 'print');
  add(35, String.fromCharCode(35), new NGFLocalizedText('井号', 'Number sign'), 'print');
  add(36, String.fromCharCode(36), new NGFLocalizedText('美元符', 'Dollar sign'), 'print');
  add(37, String.fromCharCode(37), new NGFLocalizedText('百分号', 'Percent sign'), 'print');
  add(38, String.fromCharCode(38), new NGFLocalizedText('和号', 'Ampersand'), 'print');
  add(39, String.fromCharCode(39), new NGFLocalizedText('单引号', 'Apostrophe'), 'print');
  add(40, String.fromCharCode(40), new NGFLocalizedText('左圆括号', 'Left parenthesis'), 'print');
  add(41, String.fromCharCode(41), new NGFLocalizedText('右圆括号', 'Right parenthesis'), 'print');
  add(42, String.fromCharCode(42), new NGFLocalizedText('星号', 'Asterisk'), 'print');
  add(43, String.fromCharCode(43), new NGFLocalizedText('加号', 'Plus sign'), 'print');
  add(44, String.fromCharCode(44), new NGFLocalizedText('逗号', 'Comma'), 'print');
  add(45, String.fromCharCode(45), new NGFLocalizedText('横线', 'Hyphen'), 'print');
  add(46, String.fromCharCode(46), new NGFLocalizedText('点号', 'Period'), 'print');
  add(47, SLASH, new NGFLocalizedText('斜线', 'Slash'), 'print');
  for (let d = 48; d <= 57; d++) {
  add(d, String.fromCharCode(d), new NGFLocalizedText('数字 ' + String.fromCharCode(d), 'Digit ' + String.fromCharCode(d)), 'print'); // i18n-corpus-data
  }
  add(58, String.fromCharCode(58), new NGFLocalizedText('冒号', 'Colon'), 'print');
  add(59, String.fromCharCode(59), new NGFLocalizedText('分号', 'Semicolon'), 'print');
  add(60, String.fromCharCode(60), new NGFLocalizedText('小于号', 'Less-than sign'), 'print');
  add(61, String.fromCharCode(61), new NGFLocalizedText('等号', 'Equals sign'), 'print');
  add(62, String.fromCharCode(62), new NGFLocalizedText('大于号', 'Greater-than sign'), 'print');
  add(63, String.fromCharCode(63), new NGFLocalizedText('问号', 'Question mark'), 'print');
  add(64, String.fromCharCode(64), new NGFLocalizedText('At 符', 'At sign'), 'print');
  for (let d2 = 65; d2 <= 90; d2++) {
  add(d2, String.fromCharCode(d2), new NGFLocalizedText('大写 ' + String.fromCharCode(d2), 'Uppercase ' + String.fromCharCode(d2)), 'print'); // i18n-corpus-data
  }
  add(91, String.fromCharCode(91), new NGFLocalizedText('左方括号', 'Left square bracket'), 'print');
  add(92, BACKSLASH, new NGFLocalizedText('反斜线', 'Backslash'), 'print');
  add(93, String.fromCharCode(93), new NGFLocalizedText('右方括号', 'Right square bracket'), 'print');
  add(94, String.fromCharCode(94), new NGFLocalizedText('脱字符', 'Caret'), 'print');
  add(95, String.fromCharCode(95), new NGFLocalizedText('下划线', 'Underscore'), 'print');
  add(96, String.fromCharCode(96), new NGFLocalizedText('反引号', 'Grave accent'), 'print');
  for (let d3 = 97; d3 <= 122; d3++) {
  add(d3, String.fromCharCode(d3), new NGFLocalizedText('小写 ' + String.fromCharCode(d3), 'Lowercase ' + String.fromCharCode(d3)), 'print'); // i18n-corpus-data
  }
  add(123, String.fromCharCode(123), new NGFLocalizedText('左花括号', 'Left curly brace'), 'print');
  add(124, String.fromCharCode(124), new NGFLocalizedText('竖线', 'Vertical bar'), 'print');
  add(125, String.fromCharCode(125), new NGFLocalizedText('右花括号', 'Right curly brace'), 'print');
  add(126, String.fromCharCode(126), new NGFLocalizedText('波浪线', 'Tilde'), 'print');
  return list;
}
const TABLE: Array<AsciiEntry> = buildTable();

/** 全表 */
export function allAsciiEntries(): Array<AsciiEntry> {
  return TABLE;
}

/** 分类列表 */
export function asciiCategories(): Array<string> {
  return ['ctrl', 'print'];
}

/** 查询：空关键词全表（受分类过滤）；数字/名称模糊 */
export function queryAscii(keyword: string, category: string | null): AsciiQueryResult {
  const text: string = keyword.trim().toLowerCase();
  const out: Array<AsciiEntry> = [];
  for (let i = 0; i < TABLE.length; i++) {
    const e: AsciiEntry = TABLE[i];
    if (category !== null && e.category !== category) {
      continue;
    }
    if (text.length === 0) {
      out.push(e);
      continue;
    }
    const decStr: string = String(e.decimal);
    if (decStr.indexOf(text) === 0 || e.hex.toLowerCase().indexOf(text) >= 0 ||
      e.meaning.zh.indexOf(keyword.trim()) >= 0 || e.meaning.en.toLowerCase().indexOf(text) >= 0 ||
      e.char === keyword.trim()) {
      out.push(e);
    }
  }
  return new AsciiQueryResult(out);
}