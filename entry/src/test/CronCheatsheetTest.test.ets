import { describe, expect, it } from '@ohos/hypium';
import {
  allCronEntries,
  cronCategories,
  queryCron
} from '../main/ets/tools/cron-cheatsheet/CronCheatsheetLogic';

/**
 * Cron 速查的单测：表内容事实断言 + 查询语义。
 */
export default function cronCheatsheetTest() {
  describe('cronCheatsheetTest', () => {
    it('全表 22 条且表达式唯一', 0, () => {
      const all = allCronEntries();
      expect(all.length).assertEqual(21);
      const seen = new Set<string>();
      for (let i = 0; i < all.length; i++) {
        expect(seen.has(all[i].expr)).assertEqual(false);
        seen.add(all[i].expr);
      }
    });

    it('六大分类齐全', 0, () => {
      expect(cronCategories().length).assertEqual(7);
    });

    it('关键词：每 5 分钟 命中 */5', 0, () => {
      const r = queryCron('每 5 分钟', null);
      expect(r.entries.length).assertEqual(1);
      expect(r.entries[0].expr).assertEqual('*/5 * * * *');
    });

    it('分类过滤：special 只返回特殊条目', 0, () => {
      const r = queryCron('', 'special');
      expect(r.entries.length).assertEqual(6);
      for (let i = 0; i < r.entries.length; i++) {
        expect(r.entries[i].category).assertEqual('special');
      }
    });

    it('表达式搜索不区分大小写（@DAILY 命中）', 0, () => {
      const r = queryCron('@daily', null);
      expect(r.entries.length >= 1).assertEqual(true);
    });

    it('空关键词全表；无命中空列表', 0, () => {
      expect(queryCron('', null).entries.length).assertEqual(21);
      expect(queryCron('zzzz', null).entries.length).assertEqual(0);
    });
  });
}
