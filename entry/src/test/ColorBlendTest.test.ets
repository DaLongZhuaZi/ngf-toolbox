import { describe, expect, it } from '@ohos/hypium';
import { blendColors, BlendFailureCode } from '../main/ets/tools/color-blend/ColorBlendLogic';

/**
 * 两色混合的单测：**手算锚点**（黑到白的正中间 = 808080）。
 */
export default function colorBlendTest() {
  describe('colorBlendTest', () => {
    it('黑到白、2 步：两端就是输入色', 0, () => {
      const r = blendColors('000000', 'FFFFFF', 2);
      expect(r.ok).assertEqual(true);
      expect(r.swatches.length).assertEqual(2);
      expect(r.swatches[0].hex).assertEqual('#000000');
      expect(r.swatches[1].hex).assertEqual('#FFFFFF');
    });

    it('黑到白、3 步：中点是 808080', 0, () => {
      const r = blendColors('000000', 'FFFFFF', 3);
      expect(r.swatches.length).assertEqual(3);
      expect(r.swatches[1].hex).assertEqual('#808080');
      expect(r.swatches[1].ratio).assertEqual(50);
    });

    it('红到蓝、3 步：中点手算 7F0080', 0, () => {
      const r = blendColors('FF0000', '0000FF', 3);
      // R: 255 -> 0 中点 128（四舍五入）= 0x80？ Math.round(127.5)=128=0x80
      expect(r.swatches[1].hex).assertEqual('#800080');
    });

    it('步数夹取：0 与 99 都归一到 2-12', 0, () => {
      expect(blendColors('000000', 'FFFFFF', 0).swatches.length).assertEqual(2);
      expect(blendColors('000000', 'FFFFFF', 99).swatches.length).assertEqual(12);
    });

    it('错误路径：空输入与坏色', 0, () => {
      expect(blendColors('', 'FFFFFF', 3).failure.code).assertEqual(BlendFailureCode.EMPTY_INPUT);
      expect(blendColors('zzz', 'FFFFFF', 3).failure.code).assertEqual(BlendFailureCode.BAD_COLOR);
    });
  });
}
