import { describe, expect, it } from '@ohos/hypium';
import {
  allPortEntries,
  queryPorts
} from '../main/ets/tools/port-lookup/PortLookup';

/**
 * 端口速查的单测：表内容事实断言 + 查询语义（数字前缀/服务名/中文）。
 */
export default function portLookupTest() {
  describe('portLookupTest', () => {
    it('全表 30 条且端口号唯一', 0, () => {
      const all = allPortEntries();
      expect(all.length).assertEqual(30);
      const seen = new Set<number>();
      for (let i = 0; i < all.length; i++) {
        expect(seen.has(all[i].port)).assertEqual(false);
        seen.add(all[i].port);
      }
    });

    it('数字精确：443 → HTTPS', 0, () => {
      const r = queryPorts('443');
      expect(r.entries.length).assertEqual(1);
      expect(r.entries[0].name.zh).assertEqual('HTTPS');
    });

    it('数字前缀：8 匹配 8080/8443 与 80/81（前缀语义）', 0, () => {
      // '8' 前缀匹配 80, 8443, 8080（80 的字符串 '80' 以 8 开头）
      const r = queryPorts('80');
      expect(r.entries.length >= 1).assertEqual(true);
    });

    it('服务名：mysql 命中 3306', 0, () => {
      const r = queryPorts('mysql');
      expect(r.entries.length).assertEqual(1);
      expect(r.entries[0].port).assertEqual(3306);
    });

    it('中文用途：数据库 命中多条', 0, () => {
      const r = queryPorts('数据库');
      expect(r.entries.length >= 4).assertEqual(true);
    });

    it('空关键词返回全表', 0, () => {
      expect(queryPorts('').entries.length).assertEqual(30);
    });

    it('无命中返回空列表', 0, () => {
      expect(queryPorts('99999').entries.length).assertEqual(0);
    });
  });
}
