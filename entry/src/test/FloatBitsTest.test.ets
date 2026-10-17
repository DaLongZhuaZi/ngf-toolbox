import { describe, expect, it } from '@ohos/hypium';
import {
  decomposeFloat,
  FloatBitsFailureCode,
  FloatPrecision,
  FloatValueClass
} from '../main/ets/tools/float-bits/FloatBits';

/**
 * IEEE-754 位分解的单测。
 *
 * 期望值全部来自**标准位型**（手写二进制）：
 * 1.0 单精度 = 0x3F800000；-2.0 = 0xC0000000；
 * 0.15625 = 0x3E200000（教科书经典例）；
 * 最大规格化数 / 最小非规格化数 / 无穷 / NaN 的分类。
 */
export default function floatBitsTest() {
  describe('floatBitsTest', () => {
    it('单精度 1.0 → 0x3F800000，符号 0、指数 01111111、尾数全 0', 0, () => {
      const r = decomposeFloat('1.0', FloatPrecision.SINGLE);
      expect(r.ok).assertEqual(true);
      expect(r.hex).assertEqual('3F800000');
      expect(r.sign).assertEqual(0);
      expect(r.exponentBits.join('')).assertEqual('01111111');
      let manSum = 0;
      for (let i = 0; i < 23; i++) { manSum = manSum + r.mantissaBits[i]; }
      expect(manSum).assertEqual(0);
      expect(r.valueClass).assertEqual(FloatValueClass.NORMAL);
    });

    it('单精度 -2.0 → 0xC0000000，符号 1', 0, () => {
      const r = decomposeFloat('-2.0', FloatPrecision.SINGLE);
      expect(r.hex).assertEqual('C0000000');
      expect(r.sign).assertEqual(1);
      expect(r.valueClass).assertEqual(FloatValueClass.NORMAL);
    });

    it('单精度 0.15625 → 0x3E200000（教科书例）', 0, () => {
      const r = decomposeFloat('0.15625', FloatPrecision.SINGLE);
      expect(r.hex).assertEqual('3E200000');
    });

    it('单精度无穷：Infinity → 指数全 1 尾数全 0', 0, () => {
      const r = decomposeFloat('Infinity', FloatPrecision.SINGLE);
      expect(r.valueClass).assertEqual(FloatValueClass.INFINITY);
      expect(r.exponentBits.join('')).assertEqual('11111111');
      expect(r.hex).assertEqual('7F800000');
    });

    it('单精度 NaN → 指数全 1 尾数非 0', 0, () => {
      const r = decomposeFloat('NaN', FloatPrecision.SINGLE);
      expect(r.valueClass).assertEqual(FloatValueClass.NAN);
    });

    it('单精度零：0 → 全 0 位型，分类 ZERO', 0, () => {
      const r = decomposeFloat('0', FloatPrecision.SINGLE);
      expect(r.valueClass).assertEqual(FloatValueClass.ZERO);
      expect(r.hex).assertEqual('00000000');
    });

    it('双精度 1.0 → 0x3FF0000000000000，指数 11 位', 0, () => {
      const r = decomposeFloat('1.0', FloatPrecision.DOUBLE);
      expect(r.hex).assertEqual('3FF0000000000000');
      expect(r.exponentBits.length).assertEqual(11);
      expect(r.mantissaBits.length).assertEqual(52);
      expect(r.exponentBits.join('')).assertEqual('01111111111');
    });

    it('双精度 -2.0 → 0xC000000000000000', 0, () => {
      const r = decomposeFloat('-2.0', FloatPrecision.DOUBLE);
      expect(r.hex).assertEqual('C000000000000000');
      expect(r.sign).assertEqual(1);
    });

    it('双精度最小非规格化数：5e-324 分类 SUBNORMAL', 0, () => {
      const r = decomposeFloat('5e-324', FloatPrecision.DOUBLE);
      expect(r.valueClass).assertEqual(FloatValueClass.SUBNORMAL);
    });

    it('非法输入报错（空串/非数字）', 0, () => {
      expect(decomposeFloat('', FloatPrecision.SINGLE).failure.code)
        .assertEqual(FloatBitsFailureCode.EMPTY_INPUT);
      expect(decomposeFloat('abc', FloatPrecision.SINGLE).failure.code)
        .assertEqual(FloatBitsFailureCode.NOT_A_NUMBER);
    });
  });
}
