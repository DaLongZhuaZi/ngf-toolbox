/**
 * 首页工具网格的自适应列数计算（纯逻辑）。
 *
 * ## 为什么把这点数学单独抽出来
 *
 * 「一行放几个」看起来是样式问题，实际上是**用户可感知的布局行为**：
 * 手机上 3 列、折叠屏展开或平板上 5 列、2in1 上更多——列数算错的表现是
 * 卡片被压扁到文字截断，或者右侧留一大块空白。
 *
 * 而它又完全不需要设备就能验证（给一个宽度和 vp 换算比就能算）。
 * 因此放在纯逻辑层并配单测，而不是埋进 build() 里靠真机肉眼调参。
 *
 * @module core/ToolGridLayout
 */

/** 网格布局参数 */
export class GridLayoutSpec {
  /** 卡片最小可读宽度（vp）。低于它一句话说明就会被截断。 */
  readonly minCardWidth: number;
  /** 卡片间距（vp） */
  readonly gap: number;
  /** 列数上限——即使屏幕再宽也不无限铺开，避免单张卡片宽得难读 */
  readonly maxColumns: number;

  constructor(minCardWidth: number, gap: number, maxColumns: number) {
    this.minCardWidth = minCardWidth;
    this.gap = gap;
    this.maxColumns = maxColumns;
  }

  /**
   * 默认规格。
   *
   * minCardWidth 取 156：卡片里要放「图标 + 工具名 + 一句话说明」，
   * 一句话说明按 12vp 字体大约 10~12 个汉字一行，156 是能放下
   * 「正则表达式测试、匹配高亮」这类描述的实测下限。
   */
  static standard(): GridLayoutSpec {
    return new GridLayoutSpec(156, 12, 6);
  }
}

/**
 * 按可用宽度算列数。
 *
 * 算法：`可用宽度 = 列数 × 卡片宽 + (列数 - 1) × 间距`，
 * 因此 `列数 = (可用宽度 + 间距) / (最小卡宽 + 间距)`，向下取整。
 * 这个「加间距再除」的写法避免了 n 列时少算一个间距的经典错误——
 * 如果写成 `floor(width / (min + gap))`，6 列时会比实际少放一列。
 *
 * @param availableWidthVp 可用宽度（vp）；<= 0 时返回 1（宁可窄，不要 0 列导致空白页）
 * @returns 列数，落在 [1, spec.maxColumns]
 */
export function columnsForWidth(availableWidthVp: number, spec: GridLayoutSpec): number {
  if (availableWidthVp <= 0) {
    return 1;
  }
  const effectiveMin: number = spec.minCardWidth + spec.gap;
  if (effectiveMin <= 0) {
    return 1;
  }
  const raw: number = Math.floor((availableWidthVp + spec.gap) / effectiveMin);
  if (raw < 1) {
    return 1;
  }
  return raw > spec.maxColumns ? spec.maxColumns : raw;
}

/**
 * 按列数与间距算出每张卡片的宽度。
 *
 * 用「总宽 - 全部间距」再均分，保证一行里的卡片加间距**正好**填满可用宽度，
 * 不会在右侧留下一条缝（那是网格布局最常见的视觉瑕疵）。
 *
 * @returns 卡片宽度（vp）；参数非法时退化为可用宽度本身
 */
export function cardWidthFor(availableWidthVp: number, columns: number, spec: GridLayoutSpec): number {
  if (columns <= 0 || availableWidthVp <= 0) {
    return availableWidthVp > 0 ? availableWidthVp : 0;
  }
  const totalGap: number = spec.gap * (columns - 1);
  const usable: number = availableWidthVp - totalGap;
  if (usable <= 0) {
    return availableWidthVp;
  }
  return usable / columns;
}
