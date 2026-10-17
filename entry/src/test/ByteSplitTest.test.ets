import { describe, expect, it } from '@ohos/hypium';
import {
  splitBytes,
  ByteSplitFailureCode
} from '../main/ets/tools/byte-split/ByteSplitLogic';

/**
 * 字节序演示的单测：**经典向量** 0x12345678 = 305419896。
 */
export default function byteSplitTest() {
  describe('byteSplitTest', () => {
    it('经典向量：305419896 → 大端 12 34 56 78、小端 78 56 34 12', 0, () => {
      const r = splitBytes('305419896');
      expect(r.ok).assertEqual(true);
      expect(r.hexBigEndian).assertEqual('12 34 56 78');
      expect(r.hexLittleEndian).assertEqual('78 56 34 12');
      expect(r.bytesBig[0]).assertEqual(18);
      expect(r.bytesLittle[0]).assertEqual(120);
    });

    it('0 → 全零', 0, () => {
      const r = splitBytes('0');
      expect(r.hexBigEndian).assertEqual('00 00 00 00');
      expect(r.hexLittleEndian).assertEqual('00 00 00 00');
    });

    it('最大值 4294967295 → FF FF FF FF', 0, () => {
      const r = splitBytes('4294967295');
      expect(r.hexBigEndian).assertEqual('FF FF FF FF');
    });

    it('负数与超界报错；空输入报错', 0, () => {
      expect(splitBytes('-1').failure.code).assertEqual(ByteSplitFailureCode.OUT_OF_RANGE);
      expect(splitBytes('4294967296').failure.code).assertEqual(ByteSplitFailureCode.OUT_OF_RANGE);
      expect(splitBytes('').failure.code).assertEqual(ByteSplitFailureCode.EMPTY_INPUT);
    });
  });
}
