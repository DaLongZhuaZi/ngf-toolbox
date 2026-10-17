/**
 * 正则速查表的纯逻辑实现（本地数据表）。
 *
 * ## 数据口径
 *
 * 收录常用正则语法条目（约 28 条），按分类分组：字符类/量词/分组/位置/
 * 转义/标志。每条带「语法 + 中文说明 + 示例」。
 *
 * ## 查询
 *
 * 关键词模糊匹配（语法/说明/示例），分类过滤（null = 全部）。
 *
 * @module tools/regex-cheatsheet/RegexCheatsheet
 */

import { NGFLocalizedText } from '../../core/ToolModel';

/** 一个条目 */
export class RegexEntry {
  readonly syntax: string;
  readonly meaning: NGFLocalizedText;
  readonly example: string;
  readonly category: string;

  constructor(syntax: string, meaning: NGFLocalizedText, example: string, category: string) {
    this.syntax = syntax;
    this.meaning = meaning;
    this.example = example;
    this.category = category;
  }
}

/** 查询结果 */
export class RegexQueryResult {
  readonly entries: Array<RegexEntry>;

  constructor(entries: Array<RegexEntry>) {
    this.entries = entries;
  }
}

const B: string = String.fromCharCode(92);

function buildTable(): Array<RegexEntry> {
  const list: Array<RegexEntry> = [];
  const add = (syntax: string, meaning: NGFLocalizedText, example: string, category: string): void => {
  list.push(new RegexEntry(syntax, meaning, example, category));
  };
  // 字符类
  add(B + 'd', new NGFLocalizedText('数字 0-9', 'Digit 0-9'), B + 'd+ → 123', 'char');
  add(B + 'D', new NGFLocalizedText('非数字', 'Not a digit'), B + 'D → a', 'char');
  add(B + 'w', new NGFLocalizedText('字母数字下划线', 'Word character'), B + 'w+ → abc_1', 'char');
  add(B + 'W', new NGFLocalizedText('非字母数字下划线', 'Not a word character'), B + 'W → -', 'char');
  add(B + 's', new NGFLocalizedText('空白字符', 'Whitespace'), 'a' + B + 'sb → a b', 'char');
  add(B + 'S', new NGFLocalizedText('非空白字符', 'Not whitespace'), B + 'S+ → abc', 'char');
  add('[abc]', new NGFLocalizedText('字符集合：a 或 b 或 c', 'Character set: a, b or c'), '[aeiou] → a/e/i/o/u', 'char');
  add('[^abc]', new NGFLocalizedText('否定字符集合', 'Negated character set'), '[^0-9] → x', 'char');
  add('[a-z]', new NGFLocalizedText('范围：a 到 z', 'Range: a to z'), '[A-Za-z0-9]', 'char');
  add('.', new NGFLocalizedText('任意字符（换行除外）', 'Any char except newline'), 'a.c → abc', 'char');
  // 量词
  add('*', new NGFLocalizedText('零次或多次', 'Zero or more times'), 'ab*c → ac/abc', 'quant');
  add('+', new NGFLocalizedText('一次或多次', 'One or more times'), 'ab+c → abc', 'quant');
  add('?', new NGFLocalizedText('零次或一次', 'Zero or one time'), 'colou?r → colour', 'quant');
  add('{n}', new NGFLocalizedText('恰好 n 次', 'Exactly n times'), 'd{3} → 123', 'quant');
  add('{n,}', new NGFLocalizedText('至少 n 次', 'At least n times'), 'd{2,} → 1234', 'quant');
  add('{n,m}', new NGFLocalizedText('n 到 m 次', 'Between n and m times'), 'd{2,4} → 123', 'quant');
  // 分组
  add('(abc)', new NGFLocalizedText('捕获分组', 'Capturing group'), '(d{4})-(d{2}) → 2026-01', 'group');
  add('(?:abc)', new NGFLocalizedText('非捕获分组', 'Non-capturing group'), '(?:ab)+ → abab', 'group');
  add('a|b', new NGFLocalizedText('或：a 或 b', 'Alternation: a or b'), 'cat|dog', 'group');
  // 位置
  add('^', new NGFLocalizedText('行首', 'Start of line'), '^Hello → matches at start', 'anchor');
  add('$', new NGFLocalizedText('行尾', 'End of line'), 'world$ → matches at end', 'anchor');
  add(B + 'b', new NGFLocalizedText('单词边界', 'Word boundary'), B + 'bword' + B + 'b → whole word', 'anchor');
  // 转义
  add(B + '.', new NGFLocalizedText('字面点（转义）', 'Literal dot (escaped)'), 'a' + B + '.b → a.b', 'escape');
  add(B + B, new NGFLocalizedText('字面反斜杠', 'Literal backslash'), 'C:' + B + B + 'path', 'escape');
  // 标志
  add('g', new NGFLocalizedText('全局匹配（标志）', 'Global flag'), '/a/g → all matches', 'flag');
  add('i', new NGFLocalizedText('忽略大小写（标志）', 'Case-insensitive flag'), '/abc/i → ABC', 'flag');
  add('m', new NGFLocalizedText('多行模式（标志）', 'Multiline flag'), '/^x/m → line starts', 'flag');
  add('u', new NGFLocalizedText('Unicode 模式（标志）', 'Unicode flag'), '/./u → emoji', 'flag');
  return list;
}

const TABLE: Array<RegexEntry> = buildTable();

/** 全表 */
export function allRegexEntries(): Array<RegexEntry> {
  return TABLE;
}

/** 可用分类列表（保持首次出现顺序） */
export function regexCategories(): Array<string> {
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

/** 查询：空关键词全表（受分类过滤）；文本模糊匹配语法/说明/示例 */
export function queryRegex(keyword: string, category: string | null): RegexQueryResult {
  const text: string = keyword.trim().toLowerCase();
  const out: Array<RegexEntry> = [];
  for (let i = 0; i < TABLE.length; i++) {
    const e: RegexEntry = TABLE[i];
    if (category !== null && e.category !== category) {
      continue;
    }
    if (text.length === 0 || e.syntax.toLowerCase().indexOf(text) >= 0 ||
      e.meaning.zh.toLowerCase().indexOf(text) >= 0 || e.meaning.zh.indexOf(keyword.trim()) >= 0 ||
      e.example.toLowerCase().indexOf(text) >= 0) {
      out.push(e);
    }
  }
  return new RegexQueryResult(out);
}