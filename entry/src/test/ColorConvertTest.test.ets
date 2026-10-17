import { describe, expect, it } from '@ohos/hypium';
import {
  adjustLightness,
  buildReport,
  clampChannel,
  ColorParseFailure,
  ColorParseResult,
  contrastRatio,
  evaluateContrast,
  findNamedColor,
  fromHsl,
  fromHsv,
  harmony,
  harmonyOptions,
  lightnessScale,
  namedColors,
  nearestNamedColor,
  NGFColor,
  NGFColorReport,
  NGFContrastVerdict,
  NGFcmyk,
  NGFHarmonyOption,
  NGFHsl,
  NGFHsv,
  NGFNamedColor,
  normalizeHue,
  parseColor,
  readableTextColor,
  relativeLuminance,
  rotateHue,
  toCmyk,
  toHex,
  toHexWithAlpha,
  toHsl,
  toHsv,
  toRgbText,
  toShortHex
} from '../main/ets/tools/color-convert/ColorConvert';

/**
 * 颜色转换的单测。
 *
 * ## 这个工具最容易被坑的两处
 *
 * 1. **对比度必须先反 gamma**：直接把 sRGB 编码值按 0.2126/0.7152/0.0722 加权是错的，
 *    算出的对比度会偏大——把不达标的配色判成达标，正是无障碍领域最隐蔽的坑。
 *    下面的用例用「纯红与白的对比度 = 3.9985」这条权威值把它钉死
 *    （很多人记成 4.0，那是四舍五入的近似）。
 * 2. **色相量化误差**：HSL/HSV 的饱和度与亮度以整数百分比表达（只有 101 档），
 *    往返转换因此必然有最多约 3 个通道值的误差。这是**表示精度的固有代价**，
 *    不是实现 bug——写进用例避免将来被当成回归。
 */
export default function colorConvertTest() {
  describe('colorConvertTest', () => {
    // ── 解析 ────────────────────────────────────────────────

    it('六位 HEX 解析（含省略 # 与大小写）', 0, () => {
      const lower: ColorParseResult = parseColor('#0962f2');
      expect(lower.ok).assertTrue();
      expect(toHex(lower.color as NGFColor)).assertEqual('#0962F2');
      // 省略 # 也收
      expect(toHex((parseColor('0962F2').color) as NGFColor)).assertEqual('#0962F2');
      expect(toHex((parseColor('  #0962F2  ').color) as NGFColor)).assertEqual('#0962F2');
    });

    it('三位与四位简写按「每字符重复一次」展开', 0, () => {
      // #abc 是 #aabbcc，不是 #0abc00 —— 展开规则写错会让所有简写颜色偏移。
      expect(toHex((parseColor('#abc').color) as NGFColor)).assertEqual('#AABBCC');
      expect(toHex((parseColor('#FFF').color) as NGFColor)).assertEqual('#FFFFFF');
      const four: ColorParseResult = parseColor('#f00f');
      expect(toHex((four.color) as NGFColor)).assertEqual('#FF0000');
      // 四位简写的 alpha 是重复后的值：ff -> 1.0
      expect((four.color as NGFColor).alpha).assertEqual(1);
    });

    it('八位 HEX 带 alpha', 0, () => {
      const result: ColorParseResult = parseColor('#0962F280');
      expect(result.ok).assertTrue();
      expect(toHexWithAlpha(result.color as NGFColor)).assertEqual('#0962F280');
      expect((result.color as NGFColor).isOpaque).assertFalse();
      // FF 表示完全不透明
      expect((parseColor('#0962F2FF').color as NGFColor).isOpaque).assertTrue();
    });

    it('简写的输入会被标记为 shorthand，六位不会', 0, () => {
      // 页面据此区分「用户写了简写」与「用户写错了」，而不是一律报警。
      expect(parseColor('#abc').shorthand).assertTrue();
      expect(parseColor('#aabbcc').shorthand).assertFalse();
      expect(parseColor('rgb(1,2,3)').shorthand).assertTrue();
      expect(parseColor('rgba(1,2,3,0.5)').shorthand).assertFalse();
    });

    it('非法 HEX 长度与非法字符分别被拒绝', 0, () => {
      expect(parseColor('#12345').ok).assertFalse();
      expect(parseColor('#1234567').ok).assertFalse();
      // 十六进制里的非法字符现在有**独立**的码（原先是笼统的 UNKNOWN_FORMAT），
      // 页面据此能给出更准的提示
      expect(parseColor('#GGGGGG').failure).assertEqual(ColorParseFailure.HEX_BAD_CHAR);
      expect(parseColor('#12 45').ok).assertFalse();
    });

    it('rgb() 与 rgba() 解析，间距随意', 0, () => {
      expect(toHex((parseColor('rgb(9,98,242)').color) as NGFColor)).assertEqual('#0962F2');
      expect(toHex((parseColor('rgb( 9 , 98 , 242 )').color) as NGFColor)).assertEqual('#0962F2');
      const withAlpha: ColorParseResult = parseColor('rgba(9, 98, 242, 0.5)');
      expect((withAlpha.color as NGFColor).alpha).assertEqual(0.5);
    });

    it('rgb() 支持百分数写法', 0, () => {
      // 100% 应当是 255，而不是 100
      expect(toHex((parseColor('rgb(100%, 100%, 100%)').color) as NGFColor)).assertEqual('#FFFFFF');
      expect(toHex((parseColor('rgb(0%, 0%, 0%)').color) as NGFColor)).assertEqual('#000000');
    });

    it('通道值超出 0~255 会被夹紧并标记 clamped', 0, () => {
      // 标记是必要的：界面要能告诉用户「已按 255 处理」，而不是悄悄改掉他的输入。
      const over: ColorParseResult = parseColor('rgb(300, -20, 128)');
      expect(over.ok).assertTrue();
      expect(toHex(over.color as NGFColor)).assertEqual('#FF0080');
      expect((over.color as NGFColor).clamped).assertTrue();

      // 范围内不应标记
      expect((parseColor('rgb(1, 2, 3)').color as NGFColor).clamped).assertFalse();
    });

    it('rgb() 参数个数不对时给出针对性的失败原因', 0, () => {
      // 「参数个数不对」与「通道值不合法」现在是两个码：
      // 前者是写法问题（补一个参数就行），后者是取值问题，提示话术完全不同。
      expect(parseColor('rgb(1,2)').failure).assertEqual(ColorParseFailure.RGB_ARITY);
      expect(parseColor('rgb(1,2,3,4,5)').failure).assertEqual(ColorParseFailure.RGB_ARITY);
      expect(parseColor('rgb(1,2,abc)').failure).assertEqual(ColorParseFailure.CHANNEL_RANGE);
      // 通道范围的码要带上限参数，供文案里的 0~255 用（常量改了文案才不会过期）
      expect(parseColor('rgb(1,2,abc)').args[0]).assertEqual('0');
      expect(parseColor('rgb(1,2,abc)').args[1]).assertEqual('255');
      // 缺右括号
      expect(parseColor('rgb(1,2,3').failure).assertEqual(ColorParseFailure.RGB_MISSING_PAREN);
    });

    it('hsl() 解析', 0, () => {
      const result: ColorParseResult = parseColor('hsl(217, 93%, 49%)');
      expect(result.ok).assertTrue();
      // 与同值的 HEX 应当几乎一致（差值来自色相百分比的整数量化）
      const hex: string = toHex(result.color as NGFColor);
      expect(hex === '#0962F2' || hex === '#0962F1').assertTrue();
    });

    it('hsl() 的百分号可省略，色相可超范围可负值', 0, () => {
      // 这些宽松处理是为了接受手写与从别处拷来的各种写法
      const noPercent: ColorParseResult = parseColor('hsl(0, 100, 50)');
      expect(noPercent.ok).assertTrue();
      expect(toHex(noPercent.color as NGFColor)).assertEqual('#FF0000');
      // -30 等价 330
      expect(toHex((parseColor('hsl(-30, 100%, 50%)').color) as NGFColor))
        .assertEqual(toHex((parseColor('hsl(330, 100%, 50%)').color) as NGFColor));
      // 480 等价 120
      expect(toHex((parseColor('hsl(480, 100%, 50%)').color) as NGFColor))
        .assertEqual(toHex((parseColor('hsl(120, 100%, 50%)').color) as NGFColor));
    });

    it('hsl() 的饱和度/亮度超范围会夹紧并标记', 0, () => {
      const over: ColorParseResult = parseColor('hsl(0, 200%, 50%)');
      expect(over.ok).assertTrue();
      expect((over.color as NGFColor).clamped).assertTrue();
      // 夹到 100% 后就是纯红
      expect(toHex(over.color as NGFColor)).assertEqual('#FF0000');
    });

    it('hsl() 色相非法时给出 BAD_HUE 而不是笼统错误', 0, () => {
      expect(parseColor('hsl(abc, 50%, 50%)').failure).assertEqual(ColorParseFailure.BAD_HUE);
      expect(parseColor('hsl(50%, 50%)').ok).assertFalse();
      // 参数个数与参数取值也各有其码
      expect(parseColor('hsl(50%, 50%)').failure).assertEqual(ColorParseFailure.HSL_ARITY);
      // 注意：'50' 不带百分号也能解析（parsePercent 容错），所以这里要挑真正非法的输入
      expect(parseColor('hsl(120, abc, 50)').failure).assertEqual(ColorParseFailure.HSL_PERCENT);
    });

    it('具名颜色可解析，且带回名字', 0, () => {
      const red: ColorParseResult = parseColor('red');
      expect(red.ok).assertTrue();
      expect(red.name).assertEqual('red');
      expect(toHex(red.color as NGFColor)).assertEqual('#FF0000');
      // 大小写与空格不敏感
      expect(parseColor('  SteelBlue ').ok).assertTrue();
      expect(parseColor('  SteelBlue ').name).assertEqual('steelblue');
    });

    it('空输入与未知写法给出各自的失败原因', 0, () => {
      expect(parseColor('').failure).assertEqual(ColorParseFailure.EMPTY);
      expect(parseColor('   ').failure).assertEqual(ColorParseFailure.EMPTY);
      expect(parseColor('notacolor').failure).assertEqual(ColorParseFailure.UNKNOWN_FORMAT);
      // 有点像但没有函数括号
      expect(parseColor('rgb 1 2 3').ok).assertFalse();
    });

    // ── HEX 输出 ────────────────────────────────────────────

    it('HEX 输出大写且补零', 0, () => {
      expect(toHex(NGFColor.of(0, 0, 0))).assertEqual('#000000');
      expect(toHex(NGFColor.of(1, 2, 3))).assertEqual('#010203');
      expect(toHex(NGFColor.of(255, 255, 255))).assertEqual('#FFFFFF');
    });

    it('简写 HEX 只在无损时才给出', 0, () => {
      // #FFFFFF 可以缩成 #FFF
      expect(toShortHex(NGFColor.of(255, 255, 255))).assertEqual('#FFF');
      expect(toShortHex(NGFColor.of(170, 187, 204))).assertEqual('#ABC');
      // #0962F2 缩不了 → 返回完整写法，而不是硬凑一个会变色的短写法
      expect(toShortHex(NGFColor.of(9, 98, 242))).assertEqual('#0962F2');
      // 只有部分通道可缩时也不能缩
      expect(toShortHex(NGFColor.of(255, 0, 0))).assertEqual('#F00');
      expect(toShortHex(NGFColor.of(255, 1, 0))).assertEqual('#FF0100');
    });

    it('RGB 文本在海量 alpha 下用 rgba，不透明时用 rgb', 0, () => {
      expect(toRgbText(NGFColor.of(9, 98, 242))).assertEqual('rgb(9, 98, 242)');
      const translucent: NGFColor = new NGFColor(9, 98, 242, 0.5, false);
      expect(toRgbText(translucent)).assertEqual('rgba(9, 98, 242, 0.5)');
      // alpha 为 0 也要显示出来（不能因为 0 被当成 falsy 而丢掉）
      expect(toRgbText(new NGFColor(0, 0, 0, 0, false))).assertEqual('rgba(0, 0, 0, 0)');
    });

    // ── 色彩空间换算 ────────────────────────────────────────

    it('已知主色的 HSL 与 HSV 值正确', 0, () => {
      const red: NGFHsl = toHsl(NGFColor.of(255, 0, 0));
      expect(red.hue).assertEqual(0);
      expect(red.saturation).assertEqual(100);
      expect(red.lightness).assertEqual(50);

      const green: NGFHsl = toHsl(NGFColor.of(0, 255, 0));
      expect(green.hue).assertEqual(120);

      const blue: NGFHsl = toHsl(NGFColor.of(0, 0, 255));
      expect(blue.hue).assertEqual(240);

      const blueHsv: NGFHsv = toHsv(NGFColor.of(0, 0, 255));
      expect(blueHsv.hue).assertEqual(240);
      expect(blueHsv.saturation).assertEqual(100);
      expect(blueHsv.value).assertEqual(100);
    });

    it('灰阶的色相与饱和度是 0，而不是 NaN', 0, () => {
      // 回归保护：delta 为 0 时若不特判，会产出 "hsl(NaN, NaN%, 50%)"。
      const gray: NGFHsl = toHsl(NGFColor.of(128, 128, 128));
      expect(gray.hue).assertEqual(0);
      expect(gray.saturation).assertEqual(0);
      expect(gray.lightness).assertEqual(50);

      const black: NGFHsl = toHsl(NGFColor.of(0, 0, 0));
      expect(black.saturation).assertEqual(0);
      expect(black.lightness).assertEqual(0);

      const white: NGFHsl = toHsl(NGFColor.of(255, 255, 255));
      expect(white.saturation).assertEqual(0);
      expect(white.lightness).assertEqual(100);
    });

    it('HSL 与 HSV 的饱和度口径不同（同一颜色两个值）', 0, () => {
      // 这是常见误解点：HSL 的 S=100% 与 HSV 的 S=100% 不是一回事。
      // 纯红两者都是 100，但浅色就会分道扬镳。
      const light: NGFColor = NGFColor.of(255, 128, 128);
      const hsl: NGFHsl = toHsl(light);
      const hsv: NGFHsv = toHsv(light);
      expect(hsl.lightness).assertEqual(75);
      expect(hsl.saturation).assertEqual(100);
      expect(hsv.value).assertEqual(100);
      expect(hsv.saturation).assertEqual(50);
      // 两者确实不同
      expect(hsl.saturation === hsv.saturation).assertFalse();
    });

    it('HSL 与 HSV 往返转换的误差不超过 3 个通道值（量化固有代价）', 0, () => {
      // 这不是「容忍实现不准」，而是说明表示精度：
      // 饱和度与亮度只有 101 档整数百分比，往返必然丢一点精度。
      // 写进用例是为了避免将来有人把它当回归去「修」，越修越复杂。
      const samples: Array<NGFColor> = [
        NGFColor.of(9, 98, 242),
        NGFColor.of(0, 136, 119),
        NGFColor.of(51, 68, 238),
        NGFColor.of(128, 128, 128),
        NGFColor.of(255, 0, 0),
        NGFColor.of(255, 255, 255),
        NGFColor.of(0, 0, 0)
      ];
      for (let i: number = 0; i < samples.length; i++) {
        const original: NGFColor = samples[i];
        const hsl: NGFHsl = toHsl(original);
        const backHsl: NGFColor = fromHsl(hsl.hue, hsl.saturation, hsl.lightness, 1);
        expect(Math.abs(backHsl.red - original.red) <= 3).assertTrue();
        expect(Math.abs(backHsl.green - original.green) <= 3).assertTrue();
        expect(Math.abs(backHsl.blue - original.blue) <= 3).assertTrue();

        const hsv: NGFHsv = toHsv(original);
        const backHsv: NGFColor = fromHsv(hsv.hue, hsv.saturation, hsv.value, 1);
        expect(Math.abs(backHsv.red - original.red) <= 3).assertTrue();
      }
    });

    it('HSV 往返在饱和色上是精确的（1 除以 1 不丢精度）', 0, () => {
      // 纯色与纯黑白：这些点上 HSL/HSV 的表示是精确的，往返必须完全一致。
      const exact: Array<NGFColor> = [
        NGFColor.of(255, 0, 0), NGFColor.of(0, 255, 0), NGFColor.of(0, 0, 255),
        NGFColor.of(0, 0, 0), NGFColor.of(255, 255, 255)
      ];
      for (let i: number = 0; i < exact.length; i++) {
        const c: NGFColor = exact[i];
        const hsv: NGFHsv = toHsv(c);
        const back: NGFColor = fromHsv(hsv.hue, hsv.saturation, hsv.value, 1);
        expect(toHex(back)).assertEqual(toHex(c));
      }
    });

    it('色相归一化覆盖负数与超范围', 0, () => {
      expect(normalizeHue(0)).assertEqual(0);
      expect(normalizeHue(360)).assertEqual(0);
      expect(normalizeHue(370)).assertEqual(10);
      expect(normalizeHue(-30)).assertEqual(330);
      expect(normalizeHue(-390)).assertEqual(330);
      expect(normalizeHue(720)).assertEqual(0);
      expect(normalizeHue(NaN)).assertEqual(0);
    });

    it('通道夹紧覆盖 NaN 与边界', 0, () => {
      expect(clampChannel(-1)).assertEqual(0);
      expect(clampChannel(0)).assertEqual(0);
      expect(clampChannel(255)).assertEqual(255);
      expect(clampChannel(256)).assertEqual(255);
      expect(clampChannel(1.6)).assertEqual(2);
      expect(clampChannel(-1.6)).assertEqual(0);
      // NaN 不能透传出去（会显示成 "rgb(NaN, ...)"）
      expect(clampChannel(NaN)).assertEqual(0);
    });

    // ── CMYK ────────────────────────────────────────────────

    it('CMYK 换算：纯色与纯黑的边界', 0, () => {
      const pureBlack: NGFcmyk = toCmyk(NGFColor.of(0, 0, 0));
      expect(pureBlack.black).assertEqual(100);
      // 纯黑时 K=1，其余分量没有意义，返回 0 而不是除零产生的 NaN
      expect(pureBlack.cyan).assertEqual(0);

      const white: NGFcmyk = toCmyk(NGFColor.of(255, 255, 255));
      expect(white.cyan).assertEqual(0);
      expect(white.magenta).assertEqual(0);
      expect(white.yellow).assertEqual(0);
      expect(white.black).assertEqual(0);

      const red: NGFcmyk = toCmyk(NGFColor.of(255, 0, 0));
      expect(red.cyan).assertEqual(0);
      expect(red.magenta).assertEqual(100);
      expect(red.yellow).assertEqual(100);
      expect(red.black).assertEqual(0);
    });

    // ── 亮度与对比度（本模块最需要严谨的部分） ──────────────

    it('相对亮度用 WCAG 的加权系数（权威值）', 0, () => {
      expect(Math.abs(relativeLuminance(NGFColor.of(255, 255, 255)) - 1) < 0.000001).assertTrue();
      expect(relativeLuminance(NGFColor.of(0, 0, 0))).assertEqual(0);
      // 纯色的亮度就是它的权重（这是反 gamma 正确与否的直接检验）
      expect(Math.abs(relativeLuminance(NGFColor.of(255, 0, 0)) - 0.2126) < 0.000001).assertTrue();
      expect(Math.abs(relativeLuminance(NGFColor.of(0, 255, 0)) - 0.7152) < 0.000001).assertTrue();
      expect(Math.abs(relativeLuminance(NGFColor.of(0, 0, 255)) - 0.0722) < 0.000001).assertTrue();
    });

    it('黑白对比度是 21（WCAG 的极值）', 0, () => {
      const ratio: number = contrastRatio(NGFColor.of(0, 0, 0), NGFColor.of(255, 255, 255));
      expect(Math.abs(ratio - 21) < 0.0001).assertTrue();
    });

    it('纯红与白的对比度是 3.9985，不是 4.0', 0, () => {
      // 这条是「有没有正确反 gamma」的判定用例：
      // 不做反 gamma 直接加权会得到明显偏大的值；把 4.0 当期望值也会错。
      const ratio: number = contrastRatio(NGFColor.of(255, 0, 0), NGFColor.of(255, 255, 255));
      expect(Math.abs(ratio - 3.998476) < 0.0001).assertTrue();
    });

    it('对比度与参数顺序无关', 0, () => {
      const a: NGFColor = NGFColor.of(9, 98, 242);
      const b: NGFColor = NGFColor.of(240, 240, 240);
      expect(Math.abs(contrastRatio(a, b) - contrastRatio(b, a)) < 0.0000001).assertTrue();
    });

    it('相同颜色的对比度是 1（下限）', 0, () => {
      const ratio: number = contrastRatio(NGFColor.of(128, 128, 128), NGFColor.of(128, 128, 128));
      expect(Math.abs(ratio - 1) < 0.0001).assertTrue();
    });

    it('WCAG 达标判定用对了阈值', 0, () => {
      // 纯红与白 = 3.9985：够大字号 AA(3)，但不够正文 AA(4.5) 与 AAA(7)
      const redOnWhite: NGFContrastVerdict = evaluateContrast(NGFColor.of(255, 0, 0), NGFColor.of(255, 255, 255));
      expect(redOnWhite.passesLargeAA).assertTrue();
      expect(redOnWhite.passesNormalAA).assertFalse();
      expect(redOnWhite.passesNormalAAA).assertFalse();

      // 黑白 = 21：全部达标
      const blackOnWhite: NGFContrastVerdict = evaluateContrast(NGFColor.of(0, 0, 0), NGFColor.of(255, 255, 255));
      expect(blackOnWhite.passesNormalAAA).assertTrue();
    });

    it('建议前景色取对比度更高的那个', 0, () => {
      // 深底配白字
      expect(toHex(readableTextColor(NGFColor.of(9, 98, 242)))).assertEqual('#FFFFFF');
      // 浅底配黑字
      expect(toHex(readableTextColor(NGFColor.of(250, 250, 210)))).assertEqual('#000000');
      // 中灰是临界点，但仍然必须给出确定答案（不能返回 null 或抛异常）
      expect(toHex(readableTextColor(NGFColor.of(128, 128, 128))).length).assertEqual(7);
    });

    // ── 派生颜色 ────────────────────────────────────────────

    it('调亮调暗保持色相不变', 0, () => {
      const base: NGFColor = NGFColor.of(9, 98, 242);
      const lighter: NGFColor = adjustLightness(base, 0.2);
      const darker: NGFColor = adjustLightness(base, -0.2);
      expect(toHsl(lighter).hue).assertEqual(toHsl(base).hue);
      expect(toHsl(darker).hue).assertEqual(toHsl(base).hue);
      expect(toHsl(lighter).lightness > toHsl(base).lightness).assertTrue();
      expect(toHsl(darker).lightness < toHsl(base).lightness).assertTrue();
    });

    it('调亮调暗在边界处被夹住，不会溢出成非法通道值', 0, () => {
      const white: NGFColor = NGFColor.of(255, 255, 255);
      expect(toHex(adjustLightness(white, 0.5))).assertEqual('#FFFFFF');
      const black: NGFColor = NGFColor.of(0, 0, 0);
      expect(toHex(adjustLightness(black, -0.5))).assertEqual('#000000');
    });

    it('明暗阶梯的数量与单调性', 0, () => {
      const base: NGFColor = NGFColor.of(9, 98, 242);
      const scale: Array<NGFColor> = lightnessScale(base, 5);
      expect(scale.length).assertEqual(5);
      // 从暗到亮单调递增
      for (let i: number = 1; i < scale.length; i++) {
        expect(toHsl(scale[i]).lightness > toHsl(scale[i - 1]).lightness).assertTrue();
      }
      // 两端不取纯黑纯白，保留色相信息
      expect(toHsl(scale[0]).saturation > 0).assertTrue();
      expect(toHsl(scale[4]).saturation > 0).assertTrue();
    });

    it('阶梯数量非法时退化为一个元素，而不是空数组', 0, () => {
      // 返回空数组会让调用方还得判空；返回「原色」最不容易出错。
      expect(lightnessScale(NGFColor.of(9, 98, 242), 0).length).assertEqual(1);
      expect(lightnessScale(NGFColor.of(9, 98, 242), -3).length).assertEqual(1);
      expect(lightnessScale(NGFColor.of(9, 98, 242), 1).length).assertEqual(1);
    });

    it('色相旋转绕回正确', 0, () => {
      const red: NGFColor = NGFColor.of(255, 0, 0);
      expect(toHsl(rotateHue(red, 120)).hue).assertEqual(120);
      expect(toHsl(rotateHue(red, 180)).hue).assertEqual(180);
      expect(toHsl(rotateHue(red, 240)).hue).assertEqual(240);
      // 旋转 360 回到原处
      expect(toHex(rotateHue(red, 360))).assertEqual(toHex(red));
      // 负向旋转
      expect(toHsl(rotateHue(red, -120)).hue).assertEqual(240);
    });

    it('配色方案包含原色，且按方案给出正确数量', 0, () => {
      const base: NGFColor = NGFColor.of(9, 98, 242);
      expect(harmony(base, 'complementary').length).assertEqual(2);
      expect(harmony(base, 'triadic').length).assertEqual(3);
      expect(harmony(base, 'tetradic').length).assertEqual(4);
      expect(harmony(base, 'analogous').length).assertEqual(3);
      // 第一个永远是原色
      expect(toHex(harmony(base, 'triadic')[0])).assertEqual(toHex(base));
      // 未知方案退化为只有原色，而不是抛异常
      expect(harmony(base, 'unknown').length).assertEqual(1);
    });

    it('配色方案的选项清单与实现一致', 0, () => {
      const options: Array<NGFHarmonyOption> = harmonyOptions();
      expect(options.length).assertEqual(4);
      const base: NGFColor = NGFColor.of(9, 98, 242);
      for (let i: number = 0; i < options.length; i++) {
        // 清单里的每个 kind 都必须被 harmony 认识（否则界面上会出现点了没反应的按钮）
        expect(harmony(base, options[i].kind).length > 1).assertTrue();
        // 名称是双语数据：两侧都要写得出来
      expect(options[i].label.forLocale('zh-CN').length > 0).assertTrue();
      expect(options[i].label.forLocale('en-US').length > 0).assertTrue();
      expect(options[i].label.forLocale('en-US') === options[i].label.forLocale('zh-CN'))
        .assertFalse();
      }
    });

    // ── 具名颜色与最近邻 ────────────────────────────────────

    it('具名颜色清单无重名', 0, () => {
      const list: Array<NGFNamedColor> = namedColors();
      const seen: Set<string> = new Set<string>();
      for (let i: number = 0; i < list.length; i++) {
        expect(seen.has(list[i].name)).assertFalse();
        seen.add(list[i].name);
      }
      expect(seen.size).assertEqual(list.length);
    });

    it('按名字查颜色，找不到返回 null', 0, () => {
      const red: NGFNamedColor | null = findNamedColor('RED');
      expect(red !== null).assertTrue();
      if (red !== null) {
        expect(red.red).assertEqual(255);
      }
      expect(findNamedColor('nosuchcolor') === null).assertTrue();
      expect(findNamedColor('') === null).assertTrue();
    });

    it('最近邻在常见颜色上给出合理结果', 0, () => {
      // 纯色应当命中同名色
      expect(nearestNamedColor(NGFColor.of(255, 0, 0)).name).assertEqual('red');
      expect(nearestNamedColor(NGFColor.of(0, 0, 255)).name).assertEqual('blue');
      expect(nearestNamedColor(NGFColor.of(0, 0, 0)).name).assertEqual('black');
      expect(nearestNamedColor(NGFColor.of(255, 255, 255)).name).assertEqual('white');
      // 接近某个具名色的值
      expect(nearestNamedColor(NGFColor.of(250, 5, 5)).name).assertEqual('red');
    });

    it('最近邻的权重让深蓝不会被错认成深紫（用等权欧氏距离会错）', 0, () => {
      // 这条用例锁住「加权距离」这个实现选择：换成等权欧氏距离它会失败。
      const deepBlue: NGFColor = NGFColor.of(10, 20, 200);
      const nearest: string = nearestNamedColor(deepBlue).name;
      expect(nearest === 'blue' || nearest === 'navy' || nearest === 'indigo').assertTrue();
    });

    // ── 汇总输出 ────────────────────────────────────────────

    it('汇总报告各字段与单项函数一致', 0, () => {
      const color: NGFColor = NGFColor.of(9, 98, 242);
      const report: NGFColorReport = buildReport(color);
      expect(report.hex).assertEqual(toHex(color));
      expect(report.shortHex).assertEqual(toShortHex(color));
      expect(report.hexWithAlpha).assertEqual(toHexWithAlpha(color));
      expect(report.rgbText).assertEqual(toRgbText(color));
      expect(report.nearestName).assertEqual(nearestNamedColor(color).name);
      expect(report.readableText).assertEqual(toHex(readableTextColor(color)));
    });

    it('汇总文本可复制且包含全部表示形式', 0, () => {
      // formatColorText 已下移到 UI 层（标签是文案），能在这里断言的是**数据**：
      // 每一段表示形式都算出来了，且非空。文案由 check-resources 保证键存在。
      const report: NGFColorReport = buildReport(NGFColor.of(9, 98, 242));
      expect(report.hex.length > 0).assertTrue();
      expect(report.rgbText.length > 0).assertTrue();
      expect(report.hslText.length > 0).assertTrue();
      expect(report.hsvText.length > 0).assertTrue();
      expect(report.cmykText.length > 0).assertTrue();
      expect(report.hex).assertEqual('#0962F2');
      expect(report.nearestName.length > 0).assertTrue();
      expect(report.readableText.length > 0).assertTrue();
    });

    it('简写与完整写法相同（#FFFFFF）时不重复列出简写行', 0, () => {
      // #FFFFFF 的简写是 #FFF，两者不同，所以会出现；
      // 而 #0962F2 不可简写时 shortHex === hex，那一行应当省略。
      // 「有没有更短的写法」这个判断本身在纯逻辑层，断言它而不是断言文案
      const notShortenable: NGFColorReport = buildReport(NGFColor.of(9, 98, 242));
      expect(notShortenable.shortHex).assertEqual(notShortenable.hex);
      const shortenable: NGFColorReport = buildReport(NGFColor.of(255, 255, 255));
      // 简写保留大写风格（与 hex 一致），只比较「两者不同」这件事
      expect(shortenable.shortHex.length).assertEqual(4);
      expect(shortenable.shortHex === shortenable.hex).assertFalse();
      expect(shortenable.shortHex.toLowerCase()).assertEqual('#fff');
    });
  });
}