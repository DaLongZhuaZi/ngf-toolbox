import { describe, expect, it } from '@ohos/hypium';
import {
  applyPercent,
  changeRate,
  partOfTotal,
  percentOf,
  totalFromPart,
  PercentFailureCode
} from '../main/ets/tools/percent-calc/PercentCalc';

/**
 * 百分比计算的单测：**手算基准 + 方向混淆的反例**。
 * 五个方向最容易搞混（part/total 谁除谁），每条用例的措辞都写明方向。
 */
export default function percentCalcTest() {
  describe('percentCalcTest', () => {
    it('占比：25 是 200 的 12.5%', 0, () => {
      expect(percentOf('25', '200').value).assertEqual(12.5);
    });

    it('求部分：200 的 12.5% = 25', 0, () => {
      expect(partOfTotal('200', '12.5').value).assertEqual(25);
    });

    it('增长率：100→150 = +50%；100→50 = -50%', 0, () => {
      expect(changeRate('100', '150').value).assertEqual(50);
      expect(changeRate('100', '50').value).assertEqual(-50);
    });

    it('求总数：12.5% 是 25，总数 = 200', 0, () => {
      expect(totalFromPart('25', '12.5').value).assertEqual(200);
    });

    it('加减百分比：200 加 50% = 300；300 减 50% = 150（不对称！）', 0, () => {
      expect(applyPercent('200', '50', true).value).assertEqual(300);
      expect(applyPercent('300', '50', false).value).assertEqual(150);
    });

    it('除零：占比的总数为 0、增长率的起点为 0、求总数的百分比为 0', 0, () => {
      expect(percentOf('25', '0').failure.code).assertEqual(PercentFailureCode.DIVIDE_BY_ZERO);
      expect(changeRate('0', '5').failure.code).assertEqual(PercentFailureCode.DIVIDE_BY_ZERO);
      expect(totalFromPart('25', '0').failure.code).assertEqual(PercentFailureCode.DIVIDE_BY_ZERO);
    });

    it('加减百分比的 0% 是恒等（base 不变，base=0 也合法）', 0, () => {
      expect(applyPercent('200', '0', true).value).assertEqual(200);
      expect(applyPercent('0', '50', true).value).assertEqual(0);
    });

    it('非数字与空输入报错', 0, () => {
      expect(percentOf('abc', '200').failure.code).assertEqual(PercentFailureCode.NOT_A_NUMBER);
      expect(percentOf('', '200').failure.code).assertEqual(PercentFailureCode.NOT_A_NUMBER);
    });
  });
}
