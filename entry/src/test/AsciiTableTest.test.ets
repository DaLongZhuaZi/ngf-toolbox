import { describe, expect, it } from '@ohos/hypium';
import {
  allAsciiEntries,
  asciiCategories,
  queryAscii
} from '../main/ets/tools/ascii-table/AsciiTableLogic';

/**
 * ASCII 对照表的单测：表内容事实断言 + 查询语义。
 */
export default function asciiTableTest() {
  describe('asciiTableTest', () => {
    it('全表 80 条（8 ctrl + 72 print）', 0, () => {
      const all = allAsciiEntries();
      expect(all.length).assertEqual(103);
    });

    it('两大分类', 0, () => {
      expect(asciiCategories().length).assertEqual(2);
    });

    it('十进制查：65 → 大写 A、0x41', 0, () => {
      const r = queryAscii('65', null);
      expect(r.entries.length).assertEqual(2);
      expect(r.entries[1].char).assertEqual('e');
      expect(r.entries[0].char).assertEqual('A');
      expect(r.entries[0].hex).assertEqual('0x41');
    });

    it('字符精确查：@ → 64', 0, () => {
      const r = queryAscii('@', null);
      expect(r.entries.length).assertEqual(1);
      expect(r.entries[0].decimal).assertEqual(64);
    });

    it('名称模糊：换行 命中 LF', 0, () => {
      const r = queryAscii('换行', null);
      expect(r.entries.length).assertEqual(1);
      expect(r.entries[0].decimal).assertEqual(10);
    });

    it('分类过滤：ctrl 8 条', 0, () => {
      const r = queryAscii('', 'ctrl');
      expect(r.entries.length).assertEqual(8);
    });

    it('空关键词全表；无命中空列表', 0, () => {
      expect(queryAscii('', null).entries.length).assertEqual(103);
      expect(queryAscii('zzz', null).entries.length).assertEqual(0);
    });
  });
}
