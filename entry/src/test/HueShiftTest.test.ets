import { describe, expect, it } from '@ohos/hypium';
import {
  shiftHue,
  HueShiftFailureCode
} from '../main/ets/tools/hue-shift/HueShiftLogic';

/**
 * 色相微调的单测：**手算锚点**（红 0° ±90°）+ 零偏移恒等 + 错误路径。
 */
export default function hueShiftTest() {
  describe('hueShiftTest', () => {
    it('红 0° + 90° → HSL 色相约 90（黄绿）', 0, () => {
      const r = shiftHue('#FF0000', 90, 0);
      expect(r.ok).assertEqual(true);
      expect(Math.abs(r.hue - 90) < 1).assertEqual(true);
    });

    it('红 0° - 90° → 色相约 270（紫）', 0, () => {
      const r = shiftHue('#FF0000', -90, 0);
      expect(Math.abs(r.hue - 270) < 1).assertEqual(true);
    });

    it('零偏移恒等：hex 不变', 0, () => {
      const r = shiftHue('#FF0000', 0, 0);
      expect(r.hex.toUpperCase()).assertEqual('#FF0000');
    });

    it('明度提升：L 变大', 0, () => {
      const before = shiftHue('#FF0000', 0, 0);
      const after = shiftHue('#FF0000', 0, 20);
      expect(after.lightness > before.lightness).assertEqual(true);
    });

    it('非法颜色报错；空输入报错', 0, () => {
      expect(shiftHue('not-a-color', 0, 0).failure.code).assertEqual(HueShiftFailureCode.BAD_COLOR);
      expect(shiftHue('', 0, 0).failure.code).assertEqual(HueShiftFailureCode.EMPTY_INPUT);
    });
  });
}
