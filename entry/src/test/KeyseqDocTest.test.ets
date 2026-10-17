import { describe, expect, it } from '@ohos/hypium';
import {
  allKeyseqEntries,
  keyseqCategories,
  queryKeyseq
} from '../main/ets/tools/keyseq-doc/KeyseqDocLogic';

/**
 * 快捷键速查的单测：表内容事实断言 + 查询语义。
 */
export default function keyseqDocTest() {
  describe('keyseqDocTest', () => {
    it('全表 26 条且键位唯一', 0, () => {
      const all = allKeyseqEntries();
      expect(all.length).assertEqual(26);
      const seen = new Set<string>();
      for (let i = 0; i < all.length; i++) {
        expect(seen.has(all[i].keys)).assertEqual(false);
        seen.add(all[i].keys);
      }
    });

    it('五大场景齐全', 0, () => {
      expect(keyseqCategories().length).assertEqual(5);
    });

    it('关键词：重命名 命中 Shift+F6', 0, () => {
      const r = queryKeyseq('重命名', null);
      expect(r.entries.length).assertEqual(1);
      expect(r.entries[0].keys).assertEqual('Shift+F6');
    });

    it('场景过滤：refactor 只返回重构条目（5 条）', 0, () => {
      const r = queryKeyseq('', 'refactor');
      expect(r.entries.length).assertEqual(5);
      for (let i = 0; i < r.entries.length; i++) {
        expect(r.entries[i].category).assertEqual('refactor');
      }
    });

    it('键位搜索不区分大小写', 0, () => {
      const r = queryKeyseq('ctrl+b', null);
      expect(r.entries.length).assertEqual(1);
      expect(r.entries[0].keys).assertEqual('Ctrl+B');
    });

    it('空关键词全表；无命中空列表', 0, () => {
      expect(queryKeyseq('', null).entries.length).assertEqual(26);
      expect(queryKeyseq('zzzz', null).entries.length).assertEqual(0);
    });
  });
}
