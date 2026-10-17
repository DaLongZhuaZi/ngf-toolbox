import { describe, expect, it } from '@ohos/hypium';
import { cardWidthFor, columnsForWidth, GridLayoutSpec } from '../main/ets/core/ToolGridLayout';

/**
 * 首页工具网格列数计算的单测。
 *
 * 为什么这点数学值得单测：列数算错的**表现**是「卡片被压扁、说明文字截断」
 * 或「右侧留一大块空白」，真机上很容易被当成「字体问题」而查错方向。
 * 它又是纯计算，完全没必要依赖设备。
 */
export default function toolGridLayoutTest() {
  describe('toolGridLayoutTest', () => {
    const spec: GridLayoutSpec = GridLayoutSpec.standard();

    it('按可用宽度算出列数，且不超出上下限', 0, () => {
      // 156 最小卡宽 + 12 间距 = 168 一列。
      // 360vp 手机减去左右 16 留白 = 328：
      //   (328 + 12) / 168 = 2.02 -> 2 列
      expect(columnsForWidth(328, spec)).assertEqual(2);
      // 平板 720： (720 + 12) / 168 = 4.35 -> 4 列
      expect(columnsForWidth(720, spec)).assertEqual(4);
      // 2in1 1440： (1440 + 12) / 168 = 8.6 -> 但上限是 6
      expect(columnsForWidth(1440, spec)).assertEqual(6);
    });

    it('宽度不足以放两列时退化为 1 列，而不是 0 列', 0, () => {
      // 0 列会导致整页空白，是最坏的失败方式。
      expect(columnsForWidth(100, spec)).assertEqual(1);
      expect(columnsForWidth(167, spec)).assertEqual(1);
      expect(columnsForWidth(168, spec)).assertEqual(1);
    });

    it('宽度非法时返回 1 列而不是抛异常或负数', 0, () => {
      expect(columnsForWidth(0, spec)).assertEqual(1);
      expect(columnsForWidth(-100, spec)).assertEqual(1);
    });

    it('列数边界正好卡在整倍数上时不丢列', 0, () => {
      // 这是「加间距再除」写法的核心价值：n 列时需要 n-1 个间距。
      // 若误写成 floor(width / (min + gap))，正好 n 列整倍数时会少算一列。
      const exactTwoColumns: number = 156 * 2 + 12;
      expect(columnsForWidth(exactTwoColumns, spec)).assertEqual(2);
      const exactThreeColumns: number = 156 * 3 + 12 * 2;
      expect(columnsForWidth(exactThreeColumns, spec)).assertEqual(3);
    });

    it('卡片宽度按「总宽减全部间距再均分」，保证刚好填满一行', 0, () => {
      const width: number = 328;
      const columns: number = columnsForWidth(width, spec);
      const card: number = cardWidthFor(width, columns, spec);
      // 一行总占用必须正好等于可用宽度（浮点比较留极小容差）
      const occupied: number = card * columns + spec.gap * (columns - 1);
      expect(Math.abs(occupied - width) < 0.0001).assertTrue();
    });

    it('卡片宽度在参数非法时退化为可用宽度而不是 0 或负数', 0, () => {
      expect(cardWidthFor(300, 0, spec)).assertEqual(300);
      expect(cardWidthFor(0, 3, spec)).assertEqual(0);
      // 间距比可用宽度还大时不能返回负数（负宽度会让组件渲染异常）
      expect(cardWidthFor(10, 5, spec)).assertEqual(10);
    });

    it('默认规格的最小卡宽足够放下两行说明文字', 0, () => {
      // 回归保护：若有人为了「一屏放更多」把 minCardWidth 调到 120 以下，
      // 首页卡片里的一句话说明会被截成省略号，这个断言会挡住那次改动。
      expect(spec.minCardWidth >= 150).assertTrue();
      expect(spec.maxColumns <= 6).assertTrue();
      expect(spec.gap > 0).assertTrue();
    });
  });
}
