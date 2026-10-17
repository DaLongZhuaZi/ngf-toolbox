import { describe, expect, it } from '@ohos/hypium';
import {
  checkContrast,
  judgeLevel,
  ContrastFailureCode,
  WcagLevel
} from '../main/ets/tools/contrast-check/ContrastCheck';

/**
 * 对比度检查的单测：**WCAG 已知值**。
 * 黑白对比 = 21:1（理论最大）；#777777 对白底 ≈ 4.48（AA 差一点，经典边界例）。
 */
export default function contrastCheckTest() {
  describe('contrastCheckTest', () => {
    it('黑白对比 = 21，AAA', 0, () => {
      const r = checkContrast('#000000', '#FFFFFF', false);
      expect(r.ok).assertEqual(true);
      expect(Math.abs(r.ratio - 21) < 0.01).assertEqual(true);
      expect(r.level).assertEqual(WcagLevel.AAA);
      expect(r.preferDarkText).assertEqual(true);
    });

    it('#777777 对白底 ≈ 4.48：普通文本 FAIL，大文本 AA', 0, () => {
      const r = checkContrast('#777777', '#FFFFFF', false);
      expect(r.ratio > 4.4 && r.ratio < 4.5).assertEqual(true);
      expect(r.level).assertEqual(WcagLevel.FAIL);
      const large = checkContrast('#777777', '#FFFFFF', true);
      expect(large.level).assertEqual(WcagLevel.AA_LARGE);
    });

    it('#767676 对白底 = 4.54：普通文本 AA（ Accessibility 经典边界）', 0, () => {
      const r = checkContrast('#767676', '#FFFFFF', false);
      expect(r.ratio >= 4.5).assertEqual(true);
      expect(r.level).assertEqual(WcagLevel.AA);
    });

    it('同色输入报错', 0, () => {
      const r = checkContrast('#AABBCC', '#aabbcc', false);
      expect(r.ok).assertEqual(false);
      expect(r.failure.code).assertEqual(ContrastFailureCode.SAME_COLOR);
    });

    it('3 位缩写展开：#FFF 对 #000 = 21', 0, () => {
      const r = checkContrast('#FFF', '#000', false);
      expect(Math.abs(r.ratio - 21) < 0.01).assertEqual(true);
    });

    it('preferDarkText：白底建议黑字，黑底建议白字', 0, () => {
      expect(checkContrast('#000000', '#FFFFFF', false).preferDarkText).assertEqual(true);
      expect(checkContrast('#FFFFFF', '#000000', false).preferDarkText).assertEqual(false);
    });

    it('judgeLevel：大文本阈值 3.0/4.5，普通 4.5/7.0', 0, () => {
      expect(judgeLevel(3.0, true)).assertEqual(WcagLevel.AA_LARGE);
      expect(judgeLevel(4.5, true)).assertEqual(WcagLevel.AAA);
      expect(judgeLevel(4.5, false)).assertEqual(WcagLevel.AA);
      expect(judgeLevel(7.0, false)).assertEqual(WcagLevel.AAA);
      expect(judgeLevel(2.9, false)).assertEqual(WcagLevel.FAIL);
    });

    it('空输入报错', 0, () => {
      expect(checkContrast('', '#FFFFFF', false).failure.code)
        .assertEqual(ContrastFailureCode.EMPTY_INPUT);
    });
  });
}
