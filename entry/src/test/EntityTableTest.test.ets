import { describe, expect, it } from '@ohos/hypium';
import {
  allEntityEntries,
  entityCategories,
  queryEntities
} from '../main/ets/tools/entity-table/EntityTableLogic';

/**
 * 实体速查的单测：表内容事实断言 + 查询语义。
 */
export default function entityTableTest() {
  describe('entityTableTest', () => {
    it('全表 24 条且实体唯一', 0, () => {
      const all = allEntityEntries();
      expect(all.length).assertEqual(24);
      const seen = new Set<string>();
      for (let i = 0; i < all.length; i++) {
        expect(seen.has(all[i].entity)).assertEqual(false);
        seen.add(all[i].entity);
      }
    });

    it('四大分类齐全', 0, () => {
      expect(entityCategories().length).assertEqual(4);
    });

    it('关键词：版权 命中 copy', 0, () => {
      const r = queryEntities('版权', null);
      expect(r.entries.length).assertEqual(1);
      expect(r.entries[0].entity).assertEqual('&copy;');
    });

    it('分类过滤：math 7 条', 0, () => {
      const r = queryEntities('', 'math');
      expect(r.entries.length).assertEqual(7);
    });

    it('空关键词全表；无命中空列表', 0, () => {
      expect(queryEntities('', null).entries.length).assertEqual(24);
      expect(queryEntities('zzzz', null).entries.length).assertEqual(0);
    });
  });
}
