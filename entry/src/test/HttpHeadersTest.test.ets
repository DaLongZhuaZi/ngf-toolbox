import { describe, expect, it } from '@ohos/hypium';
import {
  allHeaderEntries,
  headerCount,
  queryHeaders,
  HttpHeaderDirection
} from '../main/ets/tools/http-headers/HttpHeaders';

/**
 * HTTP 头速查的单测：表内容事实断言 + 查询语义（模糊/方向过滤/空关键词）。
 */
export default function httpHeadersTest() {
  describe('httpHeadersTest', () => {
    it('全表 24 条且头名唯一', 0, () => {
      const all = allHeaderEntries();
      expect(all.length).assertEqual(24);
      const seen = new Set<string>();
      for (let i = 0; i < all.length; i++) {
        expect(seen.has(all[i].name)).assertEqual(false);
        seen.add(all[i].name);
      }
    });

    it('headerCount 与全表一致', 0, () => {
      expect(headerCount()).assertEqual(allHeaderEntries().length);
    });

    it('三种方向都有条目', 0, () => {
      const all = allHeaderEntries();
      const dirs = new Set<string>();
      for (let i = 0; i < all.length; i++) {
        dirs.add(all[i].direction);
      }
      expect(dirs.size).assertEqual(3);
    });

    it('关键词：cache 命中 Cache-Control', 0, () => {
      const r = queryHeaders('cache', null);
      let found = false;
      for (let i = 0; i < r.entries.length; i++) {
        if (r.entries[i].name === 'Cache-Control') { found = true; }
      }
      expect(found).assertEqual(true);
    });

    it('中文含义：跨域 命中 CORS 两条', 0, () => {
      const r = queryHeaders('CORS', null);
      expect(r.entries.length).assertEqual(2);
    });

    it('方向过滤：REQUEST 不含仅响应头（Location）', 0, () => {
      const r = queryHeaders('', HttpHeaderDirection.REQUEST);
      for (let i = 0; i < r.entries.length; i++) {
        expect(r.entries[i].name === 'Location').assertEqual(false);
      }
    });

    it('空关键词 + 无方向过滤 = 全表', 0, () => {
      expect(queryHeaders('', null).entries.length).assertEqual(24);
    });

    it('无命中返回空列表', 0, () => {
      expect(queryHeaders('zzzz', null).entries.length).assertEqual(0);
    });
  });
}
