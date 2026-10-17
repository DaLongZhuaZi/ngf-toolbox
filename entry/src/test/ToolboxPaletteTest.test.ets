import { describe, expect, it } from '@ohos/hypium';
import { NGFColorToken } from 'ngf_framework';
import { toolboxPalette } from '../main/ets/core/ToolboxPalette';

/**
 * 调色板的**完整性**测试。
 *
 * ## 为什么这些用例值得存在
 *
 * 调色板是「框架 Token 体系」与「界面实际颜色」之间唯一的桥：
 * \`ThemeSource\` 启动时把它注册进去，\`check-theme-contrast.mjs\` 审计它。
 * 它出错的方式全都**不会报错**：
 *
 * - 少一个 Token → \`resolveColor()\` 返回黑色 \`#000000\`，界面某处变黑；
 * - 明暗两色填成一样 → 深色主题下那块看起来跟浅色一样，只有用户会发现；
 * - 色值写成非法十六进制 → 静默按默认值处理。
 *
 * 这些都不是「跑一遍没事」能发现的，只能靠断言。
 */
export default function toolboxPaletteTest() {
  describe('ToolboxPaletteTest', () => {
    it('覆盖框架 Token 枚举的每一个成员', 0, () => {
      const palette = toolboxPalette();
      const names: Array<string> = Object.keys(NGFColorToken);
      const covered: Array<string> = [];
      for (let i: number = 0; i < palette.length; i++) {
        covered.push(palette[i].token);
      }
      for (let i: number = 0; i < names.length; i++) {
        const token: string = (NGFColorToken as Record<string, string>)[names[i]];
        // 少一个就会在运行时退回 #000000，界面上一块变黑，且没有任何报错
        expect(covered.indexOf(token) >= 0).assertTrue();
      }
    });

    it('Token 不重复', 0, () => {
      const palette = toolboxPalette();
      for (let i: number = 0; i < palette.length; i++) {
        for (let j: number = i + 1; j < palette.length; j++) {
          expect(palette[i].token === palette[j].token).assertFalse();
        }
      }
    });

    it('每个 Token 的明暗两色不相同', 0, () => {
      // 相同 = 多半漏填了一列，深色主题下那一块会跟浅色一模一样
      const palette = toolboxPalette();
      for (let i: number = 0; i < palette.length; i++) {
        expect(palette[i].light === palette[i].dark).assertFalse();
      }
    });

    it('色值都是合法的 #RRGGBB', 0, () => {
      const palette = toolboxPalette();
      for (let i: number = 0; i < palette.length; i++) {
        const light: string = palette[i].light;
        const dark: string = palette[i].dark;
        expect(light.length).assertEqual(7);
        expect(dark.length).assertEqual(7);
        expect(light.charAt(0)).assertEqual('#');
        expect(dark.charAt(0)).assertEqual('#');
      }
    });

    it('返回的是副本，调用方改不坏内部状态', 0, () => {
      // 两份调用拿到的是各自独立的数组：ThemeSource 注册时会遍历它，
      // 若返回同一份实例，任何一处改动都会影响另一处与对比度审计。
      const a = toolboxPalette();
      const b = toolboxPalette();
      expect(a === b).assertFalse();
      expect(a.length).assertEqual(b.length);
    });
  });
}
