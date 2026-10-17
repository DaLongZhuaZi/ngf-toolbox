import { describe, expect, it } from '@ohos/hypium';
import {
  allMethodEntries,
  queryMethods
} from '../main/ets/tools/http-method/HttpMethodLogic';

/**
 * HTTP 方法速查的单测：表内容事实断言（九方法/幂等性标记正确）+ 查询语义。
 */
export default function httpMethodTest() {
  describe('httpMethodTest', () => {
    it('全表 9 条且方法唯一', 0, () => {
      const all = allMethodEntries();
      expect(all.length).assertEqual(9);
      const seen = new Set<string>();
      for (let i = 0; i < all.length; i++) {
        expect(seen.has(all[i].method)).assertEqual(false);
        seen.add(all[i].method);
      }
    });

    it('幂等性：GET/PUT/DELETE/HEAD/OPTIONS/TRACE 幂等，POST/PATCH 不幂等', 0, () => {
      const all = allMethodEntries();
      for (let i = 0; i < all.length; i++) {
        const m = all[i].method;
        if (m === 'POST' || m === 'PATCH' || m === 'CONNECT') {
          expect(all[i].idempotent).assertEqual(false);
        } else {
          expect(all[i].idempotent).assertEqual(true);
        }
      }
    });

    it('关键词：创建 命中 POST', 0, () => {
      const r = queryMethods('创建');
      expect(r.entries.length).assertEqual(1);
      expect(r.entries[0].method).assertEqual('POST');
    });

    it('关键词：patch 大小写不敏感', 0, () => {
      const r = queryMethods('patch');
      expect(r.entries.length).assertEqual(1);
      expect(r.entries[0].method).assertEqual('PATCH');
    });

    it('空关键词全表；无命中空列表', 0, () => {
      expect(queryMethods('').entries.length).assertEqual(9);
      expect(queryMethods('zzzz').entries.length).assertEqual(0);
    });
  });
}
