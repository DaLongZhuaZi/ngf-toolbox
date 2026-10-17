import { describe, expect, it } from '@ohos/hypium';
import {
  generatePalette,
  PaletteFailureCode
} from '../main/ets/tools/palette-gen/PaletteGen';

/**
 * 色板生成的单测：**结构断言**（分组数、每组 5 档、主色居中）
 * + 具体色值断言（0x 基色明暗阶梯的端点可手算）。
 */
export default function paletteGenTest() {
  describe('paletteGenTest', () => {
    it('空 harmonyKind：只有主色一组 5 档', 0, () => {
      const r = generatePalette('#FF0000', '');
      expect(r.ok).assertEqual(true);
      expect(r.groups.length).assertEqual(1);
      expect(r.groups[0].length).assertEqual(5);
    });

    it('complementary：主色组 + 1 个和谐组', 0, () => {
      const r = generatePalette('#FF0000', 'complementary');
      expect(r.groups.length).assertEqual(2);
    });

    it('triadic：主色组 + 2 个和谐组', 0, () => {
      const r = generatePalette('#FF0000', 'triadic');
      expect(r.groups.length).assertEqual(3);
    });

    it('tetradic：主色组 + 3 个和谐组', 0, () => {
      const r = generatePalette('#FF0000', 'tetradic');
      expect(r.groups.length).assertEqual(4);
    });

    it('analogous：主色组 + 2 个和谐组（-30/+30）', 0, () => {
      const r = generatePalette('#FF0000', 'analogous');
      expect(r.groups.length).assertEqual(3);
    });

    it('主色标记在 5 档的中间（index 2）', 0, () => {
      const r = generatePalette('#FF0000', '');
      let baseCount = 0;
      for (let i = 0; i < r.groups[0].length; i++) {
        if (r.groups[0][i].isBase) {
          baseCount++;
          expect(i).assertEqual(2);
        }
      }
      expect(baseCount).assertEqual(1);
    });

    it('非法颜色报错', 0, () => {
      expect(generatePalette('not-a-color', '').failure.code)
        .assertEqual(PaletteFailureCode.BAD_COLOR);
      expect(generatePalette('', '').failure.code)
        .assertEqual(PaletteFailureCode.EMPTY_INPUT);
    });

    it('红色 #FF0000 的阶梯：中间档是原色 FF0000', 0, () => {
      const r = generatePalette('#FF0000', '');
      // 中间档（index 2）是原色
      expect(r.groups[0][2].hex.toUpperCase()).assertEqual('#FF0000');
    });
  });
}
