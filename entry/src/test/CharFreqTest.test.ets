import { describe, expect, it } from '@ohos/hypium';
import {
  analyzeFrequency,
  CharFreqFailureCode
} from '../main/ets/tools/char-frequency/CharFreqLogic';

/**
 * 字符频率的单测：计数/排序/选项/确定性。
 */
export default function charFreqTest() {
  describe('charFreqTest', () => {
    it('基本计数：aab → a=2 b=1（降序）', 0, () => {
      const r = analyzeFrequency('aab', false, true);
      expect(r.ok).assertEqual(true);
      expect(r.items[0].char).assertEqual('a');
      expect(r.items[0].count).assertEqual(2);
      expect(r.items[1].count).assertEqual(1);
      expect(r.total).assertEqual(3);
      expect(r.unique).assertEqual(2);
    });

    it('占比：a 占 66.67%', 0, () => {
      const r = analyzeFrequency('aab', false, true);
      expect(r.items[0].percent).assertEqual('66.67');
    });

    it('ignoreCase：Aa 合并为 a=2', 0, () => {
      const r = analyzeFrequency('Aa', true, true);
      expect(r.unique).assertEqual(1);
      expect(r.items[0].count).assertEqual(2);
    });

    it('ignoreWhitespace：空白跳过', 0, () => {
      const r = analyzeFrequency('a b' + String.fromCharCode(10) + 'c', false, true);
      expect(r.total).assertEqual(3);
    });

    it('不忽略空白：空格计入', 0, () => {
      const r = analyzeFrequency('a b', false, false);
      expect(r.total).assertEqual(3);
    });

    it('排序确定性：次数相同按字符码升序', 0, () => {
      const r = analyzeFrequency('cba', false, true);
      expect(r.items[0].char).assertEqual('a');
      expect(r.items[1].char).assertEqual('b');
      expect(r.items[2].char).assertEqual('c');
    });

    it('空输入报错', 0, () => {
      expect(analyzeFrequency('', false, false).failure.code)
        .assertEqual(CharFreqFailureCode.EMPTY_INPUT);
    });
  });
}
