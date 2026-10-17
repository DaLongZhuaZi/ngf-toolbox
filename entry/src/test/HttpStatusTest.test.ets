import { describe, expect, it } from '@ohos/hypium';
import {
  allStatusEntries,
  queryStatus
} from '../main/ets/tools/http-status/HttpStatus';

/**
 * HTTP 状态码速查的单测：**表内容的事实断言**（码值、分类、数量）
 * 与查询语义（数字前缀 / 文本模糊 / 空关键词全表）。
 */
export default function httpStatusTest() {
  describe('httpStatusTest', () => {
    it('全表 23 条且按码升序', 0, () => {
      const all = allStatusEntries();
      expect(all.length).assertEqual(23);
      for (let i = 1; i < all.length; i++) {
        expect(all[i].code > all[i - 1].code).assertEqual(true);
      }
    });

    it('五大分类都有条目', 0, () => {
      const all = allStatusEntries();
      const cats = new Set<number>();
      for (let i = 0; i < all.length; i++) {
        cats.add(all[i].category);
      }
      expect(cats.size).assertEqual(5);
    });

    it('数字精确：404', 0, () => {
      const r = queryStatus('404');
      expect(r.entries.length).assertEqual(1);
      expect(r.entries[0].name).assertEqual('Not Found');
    });

    it('数字前缀：40 匹配 400/401/403/404/405/408/409（7 条）', 0, () => {
      const r = queryStatus('40');
      expect(r.entries.length).assertEqual(7);
    });

    it('文本模糊：found 命中 302/404', 0, () => {
      const r = queryStatus('found');
      expect(r.entries.length).assertEqual(2);
    });

    it('中文模糊：重定向 命中 301/302', 0, () => {
      const r = queryStatus('重定向');
      expect(r.entries.length).assertEqual(2);
    });

    it('空关键词返回全表', 0, () => {
      expect(queryStatus('').entries.length).assertEqual(23);
      expect(queryStatus('   ').entries.length).assertEqual(23);
    });

    it('大小写不敏感：BEARER 命中 401 的原因', 0, () => {
      const r = queryStatus('BEARER');
      expect(r.entries.length).assertEqual(1);
      expect(r.entries[0].code).assertEqual(401);
    });

    it('无命中返回空列表（合法状态）', 0, () => {
      expect(queryStatus('99999').entries.length).assertEqual(0);
      expect(queryStatus('zzzz').entries.length).assertEqual(0);
    });
  });
}
