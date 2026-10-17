import { describe, expect, it } from '@ohos/hypium';
import {
  allRegexEntries,
  queryRegex,
  regexCategories
} from '../main/ets/tools/regex-cheatsheet/RegexCheatsheet';

const B = String.fromCharCode(92);

/**
 * 正则速查的单测：表内容事实断言（数量/分类/唯一性）+ 查询语义。
 */
export default function regexCheatsheetTest() {
  describe('regexCheatsheetTest', () => {
    it('全表 28 条且语法唯一', 0, () => {
      const all = allRegexEntries();
      expect(all.length).assertEqual(28);
      const seen = new Set<string>();
      for (let i = 0; i < all.length; i++) {
        expect(seen.has(all[i].syntax + '|' + all[i].category)).assertEqual(false);
        seen.add(all[i].syntax + '|' + all[i].category);
      }
    });

    it('六大分类齐全且保持首次出现顺序', 0, () => {
      const cats = regexCategories();
      expect(cats.length).assertEqual(6);
      expect(cats[0]).assertEqual('char');
      expect(cats[5]).assertEqual('flag');
    });

    it('关键词：数字 命中 ' + B + 'd', 0, () => {
      const r = queryRegex('数字', null);
      let found = false;
      for (let i = 0; i < r.entries.length; i++) {
        if (r.entries[i].syntax === B + 'd') { found = true; }
      }
      expect(found).assertEqual(true);
    });

    it('关键词：捕获 命中捕获分组', 0, () => {
      const r = queryRegex('捕获', null);
      expect(r.entries.length >= 1).assertEqual(true);
    });

    it('分类过滤：flag 只返回标志条目', 0, () => {
      const r = queryRegex('', 'flag');
      expect(r.entries.length).assertEqual(4);
      for (let i = 0; i < r.entries.length; i++) {
        expect(r.entries[i].category).assertEqual('flag');
      }
    });

    it('空关键词全表', 0, () => {
      expect(queryRegex('', null).entries.length).assertEqual(28);
    });

    it('无命中返回空列表', 0, () => {
      expect(queryRegex('zzzz', null).entries.length).assertEqual(0);
    });

    it('转义条目内容含反斜杠', 0, () => {
      const r = queryRegex('字面反斜杠', null);
      expect(r.entries.length).assertEqual(1);
      expect(r.entries[0].syntax).assertEqual(B + B);
    });
  });
}