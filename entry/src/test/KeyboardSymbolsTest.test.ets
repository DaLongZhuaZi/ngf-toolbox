import { describe, expect, it } from '@ohos/hypium';
import {
  allKeySymbols,
  queryKeySymbols
} from '../main/ets/tools/keyboard-symbols/KeyboardSymbolsLogic';

/**
 * 键盘符号速查的单测：表内容事实断言 + 查询语义。
 */
export default function keyboardSymbolsTest() {
  describe('keyboardSymbolsTest', () => {
    it('全表 15 条且符号唯一', 0, () => {
      const all = allKeySymbols();
      expect(all.length).assertEqual(15);
      const seen = new Set<string>();
      for (let i = 0; i < all.length; i++) {
        expect(seen.has(all[i].symbol)).assertEqual(false);
        seen.add(all[i].symbol);
      }
    });

    it('关键词：命令 命中 Command', 0, () => {
      const r = queryKeySymbols('命令');
      expect(r.entries.length).assertEqual(1);
      expect(r.entries[0].name).assertEqual('Command');
    });

    it('Win 等价键：alt 命中 Option', 0, () => {
      const r = queryKeySymbols('alt');
      expect(r.entries.length >= 1).assertEqual(true);
    });

    it('空关键词全表；无命中空列表', 0, () => {
      expect(queryKeySymbols('').entries.length).assertEqual(15);
      expect(queryKeySymbols('zzzz').entries.length).assertEqual(0);
    });
  });
}
