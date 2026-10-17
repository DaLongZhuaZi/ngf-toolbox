import { describe, expect, it } from '@ohos/hypium';
import {
  allMimeEntries,
  lookupMime,
  normalizeExtension
} from '../main/ets/tools/mime-lookup/MimeLookup';

/**
 * MIME 速查的单测：表内容事实断言 + 归一化语义（带点/文件名/大小写）。
 */
export default function mimeLookupTest() {
  describe('mimeLookupTest', () => {
    it('全表 30 条且扩展名唯一', 0, () => {
      const all = allMimeEntries();
      expect(all.length).assertEqual(30);
      const seen = new Set<string>();
      for (let i = 0; i < all.length; i++) {
        expect(seen.has(all[i].extension)).assertEqual(false);
        seen.add(all[i].extension);
      }
    });

    it('基本查询：json / png', 0, () => {
      expect(lookupMime('json').entry.mime).assertEqual('application/json');
      expect(lookupMime('png').entry.mime).assertEqual('image/png');
    });

    it('带点的文件名取最后一段扩展名', 0, () => {
      expect(lookupMime('app.min.js').entry.mime).assertEqual('text/javascript');
      expect(lookupMime('data.tar.gz').entry.mime).assertEqual('application/gzip');
    });

    it('大小写不敏感：JSON / Png', 0, () => {
      expect(lookupMime('JSON').entry.mime).assertEqual('application/json');
      expect(lookupMime('PnG').entry.mime).assertEqual('image/png');
    });

    it('jpg 与 jpeg 都映射 image/jpeg', 0, () => {
      expect(lookupMime('jpg').entry.mime).assertEqual(lookupMime('jpeg').entry.mime);
    });

    it('未命中 found=false', 0, () => {
      expect(lookupMime('xyzunknown').found).assertEqual(false);
      expect(lookupMime('').found).assertEqual(false);
    });

    it('normalizeExtension：点/无点/多点', 0, () => {
      expect(normalizeExtension('.json')).assertEqual('json');
      expect(normalizeExtension('json')).assertEqual('json');
      expect(normalizeExtension('a.b.json')).assertEqual('json');
    });
  });
}
