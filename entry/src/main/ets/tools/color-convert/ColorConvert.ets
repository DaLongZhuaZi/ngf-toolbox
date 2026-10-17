/**
 * 颜色转换 —— 纯逻辑（零 import，可直接单测）。
 *
 * ## 色彩空间口径（必须讲清楚，否则数字会「看起来对、实际不对」）
 *
 * 本模块的一切换算都在 **sRGB** 空间内做，通道值按 0~255 的**编码值**（gamma 已编码）
 * 存储。这一点在 {@link relativeLuminance} 里尤其关键：对比度计算必须先把编码值
 * **反 gamma** 还原成线性光强，否则算出来的对比度会系统性偏大——
 * 那是 WCAG 无障碍校验里最常见的实现错误，会让「不达标」的颜色被判成达标。
 *
 * ## 为什么不使用任何设备 API
 *
 * 颜色换算完全可以用整数与浮点算术表达，不需要色彩管理框架。
 * 保持零依赖的直接收益是：整块逻辑能在 entry/src/test 里跑单测，
 * 而且不会因为设备色彩配置不同而给出不同结果（工具给的是标准 sRGB 值，
 * 不是「本机看起来如何」）。真正的色彩管理（ICC、P3 广色域）本工具不做，
 * 已在工具边界里写明。
 *
 * @module tools/color-convert/ColorConvert
 */

import { NGFLocalizedText } from '../../core/ToolModel';

/** 单个通道的最大编码值 */
const CHANNEL_MAX: number = 255;
/** 每轮 60 度 */
const DEGREES_PER_SECTOR: number = 60;

/** 一个颜色（sRGB，通道 0~255，alpha 0~1） */
export class NGFColor {
  readonly red: number;
  readonly green: number;
  readonly blue: number;
  /** 0~1；解析不出来时默认 1（不透明） */
  readonly alpha: number;
  /** 解析时是否发生过截断（例如 hsl(0, 200%, 50%) 的饱和度被夹到 100%） */
  readonly clamped: boolean;

  constructor(red: number, green: number, blue: number, alpha: number, clamped: boolean) {
    this.red = red;
    this.green = green;
    this.blue = blue;
    this.alpha = alpha;
    this.clamped = clamped;
  }

  static of(red: number, green: number, blue: number): NGFColor {
    return new NGFColor(clampChannel(red), clampChannel(green), clampChannel(blue), 1, false);
  }

  /** 是否为不透明颜色 */
  get isOpaque(): boolean {
    return this.alpha >= 1;
  }
}

/** 把通道值夹到 0~255 并取整 */
export function clampChannel(value: number): number {
  if (isNaN(value)) {
    return 0;
  }
  const rounded: number = Math.round(value);
  if (rounded < 0) {
    return 0;
  }
  return rounded > CHANNEL_MAX ? CHANNEL_MAX : rounded;
}

/** 把 0~1 的比例夹到范围内 */
function clampRatio(value: number): number {
  if (isNaN(value)) {
    return 0;
  }
  if (value < 0) {
    return 0;
  }
  return value > 1 ? 1 : value;
}

// ── HEX ──────────────────────────────────────────────────────

/** 两位十六进制 */
function byteToHex(value: number): string {
  const clamped: number = clampChannel(value);
  const digits: string = '0123456789ABCDEF';
  return digits.charAt(Math.floor(clamped / 16)) + digits.charAt(clamped % 16);
}

/** 单个字符转十六进制数值；非法返回 -1 */
function hexDigitValue(ch: string): number {
  const code: number = ch.charCodeAt(0);
  if (code >= 48 && code <= 57) {
    return code - 48;
  }
  if (code >= 65 && code <= 70) {
    return code - 55;
  }
  if (code >= 97 && code <= 102) {
    return code - 87;
  }
  return -1;
}

/** 颜色 → #RRGGBB（不含 alpha） */
export function toHex(color: NGFColor): string {
  return '#' + byteToHex(color.red) + byteToHex(color.green) + byteToHex(color.blue);
}

/** 颜色 → #RRGGBBAA */
export function toHexWithAlpha(color: NGFColor): string {
  return toHex(color) + byteToHex(Math.round(clampRatio(color.alpha) * CHANNEL_MAX));
}

/** 颜色 → #RGB（仅当三通道都能用单字符表示时才是无损简写） */
export function toShortHex(color: NGFColor): string {
  const full: string = toHex(color);
  const r1: string = full.charAt(1);
  const r2: string = full.charAt(2);
  const g1: string = full.charAt(3);
  const g2: string = full.charAt(4);
  const b1: string = full.charAt(5);
  const b2: string = full.charAt(6);
  if (r1 === r2 && g1 === g2 && b1 === b2) {
    return '#' + r1 + g1 + b1;
  }
  // 不能无损简写时返回完整写法，而不是硬凑一个会变色的短写法
  return full;
}

// ── RGB ──────────────────────────────────────────────────────

/** 颜色 → rgb(r, g, b) 或 rgba(r, g, b, a) */
export function toRgbText(color: NGFColor): string {
  if (color.isOpaque) {
    return 'rgb(' + String(color.red) + ', ' + String(color.green) + ', ' + String(color.blue) + ')';
  }
  return 'rgba(' + String(color.red) + ', ' + String(color.green) + ', ' + String(color.blue)
    + ', ' + formatAlpha(color.alpha) + ')';
}

/** alpha 的显示写法：去掉多余的零，最多两位小数 */
function formatAlpha(alpha: number): string {
  const rounded: number = Math.round(clampRatio(alpha) * 100) / 100;
  return String(rounded);
}

// ── HSL / HSV ────────────────────────────────────────────────

/** HSL 表示（色相 0~360，饱和度与亮度 0~100） */
export class NGFHsl {
  readonly hue: number;
  readonly saturation: number;
  readonly lightness: number;

  constructor(hue: number, saturation: number, lightness: number) {
    this.hue = hue;
    this.saturation = saturation;
    this.lightness = lightness;
  }
}

/** HSV 表示（色相 0~360，饱和度与明度 0~100） */
export class NGFHsv {
  readonly hue: number;
  readonly saturation: number;
  readonly value: number;

  constructor(hue: number, saturation: number, value: number) {
    this.hue = hue;
    this.saturation = saturation;
    this.value = value;
  }
}

/** 颜色 → HSL */
export function toHsl(color: NGFColor): NGFHsl {
  const r: number = color.red / CHANNEL_MAX;
  const g: number = color.green / CHANNEL_MAX;
  const b: number = color.blue / CHANNEL_MAX;
  const max: number = Math.max(r, Math.max(g, b));
  const min: number = Math.min(r, Math.min(g, b));
  const lightness: number = (max + min) / 2;
  const delta: number = max - min;

  // 灰阶（含纯黑纯白）：色相与饱和度都是 0，而不是 NaN。
  // 这是最容易漏的分支：delta 为 0 时除以它会得到 NaN，显示成 "hsl(NaN, ...)"。
  if (delta === 0) {
    return new NGFHsl(0, 0, Math.round(lightness * 100));
  }

  const saturation: number = lightness > 0.5
    ? delta / (2 - max - min)
    : delta / (max + min);
  let hue: number = 0;
  if (max === r) {
    hue = ((g - b) / delta) % 6;
  } else if (max === g) {
    hue = (b - r) / delta + 2;
  } else {
    hue = (r - g) / delta + 4;
  }
  hue = hue * DEGREES_PER_SECTOR;
  if (hue < 0) {
    hue += 360;
  }
  return new NGFHsl(Math.round(hue), Math.round(saturation * 100), Math.round(lightness * 100));
}

/** 颜色 → HSV */
export function toHsv(color: NGFColor): NGFHsv {
  const r: number = color.red / CHANNEL_MAX;
  const g: number = color.green / CHANNEL_MAX;
  const b: number = color.blue / CHANNEL_MAX;
  const max: number = Math.max(r, Math.max(g, b));
  const min: number = Math.min(r, Math.min(g, b));
  const delta: number = max - min;
  const value: number = max;
  if (delta === 0) {
    return new NGFHsv(0, 0, Math.round(value * 100));
  }
  const saturation: number = max === 0 ? 0 : delta / max;
  let hue: number = 0;
  if (max === r) {
    hue = ((g - b) / delta) % 6;
  } else if (max === g) {
    hue = (b - r) / delta + 2;
  } else {
    hue = (r - g) / delta + 4;
  }
  hue = hue * DEGREES_PER_SECTOR;
  if (hue < 0) {
    hue += 360;
  }
  return new NGFHsv(Math.round(hue), Math.round(saturation * 100), Math.round(value * 100));
}

/**
 * HSL → 颜色。
 *
 * 色相会自动取模到 0~360（-30 等价于 330），饱和度与亮度超出时夹紧并**标记 clamped**——
 * 标记是刻意的：用户写了 120% 的饱和度，界面要能告诉他「已按 100% 处理」，
 * 而不是悄悄改掉。
 */
export function fromHsl(hue: number, saturation: number, lightness: number, alpha: number): NGFColor {
  const normalizedHue: number = normalizeHue(hue);
  const clampedSaturation: boolean = saturation > 100 || saturation < 0;
  const clampedLightness: boolean = lightness > 100 || lightness < 0;
  const s: number = clampRatio(saturation / 100);
  const l: number = clampRatio(lightness / 100);

  if (s === 0) {
    const gray: number = Math.round(l * CHANNEL_MAX);
    return new NGFColor(gray, gray, gray, clampRatio(alpha), clampedSaturation || clampedLightness);
  }

  const q: number = l < 0.5 ? l * (1 + s) : l + s - l * s;
  const p: number = 2 * l - q;
  const hk: number = normalizedHue / 360;
  const red: number = hueToChannel(p, q, hk + 1 / 3);
  const green: number = hueToChannel(p, q, hk);
  const blue: number = hueToChannel(p, q, hk - 1 / 3);
  return new NGFColor(
    clampChannel(red * CHANNEL_MAX),
    clampChannel(green * CHANNEL_MAX),
    clampChannel(blue * CHANNEL_MAX),
    clampRatio(alpha),
    clampedSaturation || clampedLightness
  );
}

/** HSV → 颜色 */
export function fromHsv(hue: number, saturation: number, value: number, alpha: number): NGFColor {
  const normalizedHue: number = normalizeHue(hue);
  const clampedSaturation: boolean = saturation > 100 || saturation < 0;
  const clampedValue: boolean = value > 100 || value < 0;
  const s: number = clampRatio(saturation / 100);
  const v: number = clampRatio(value / 100);

  const c: number = v * s;
  const hk: number = normalizedHue / DEGREES_PER_SECTOR;
  const x: number = c * (1 - Math.abs((hk % 2) - 1));
  let r1: number = 0;
  let g1: number = 0;
  let b1: number = 0;
  if (hk < 1) {
    r1 = c; g1 = x;
  } else if (hk < 2) {
    r1 = x; g1 = c;
  } else if (hk < 3) {
    g1 = c; b1 = x;
  } else if (hk < 4) {
    g1 = x; b1 = c;
  } else if (hk < 5) {
    r1 = x; b1 = c;
  } else {
    r1 = c; b1 = x;
  }
  const m: number = v - c;
  return new NGFColor(
    clampChannel((r1 + m) * CHANNEL_MAX),
    clampChannel((g1 + m) * CHANNEL_MAX),
    clampChannel((b1 + m) * CHANNEL_MAX),
    clampRatio(alpha),
    clampedSaturation || clampedValue
  );
}

/** 把色相归一化到 0~360（含负数与超范围） */
export function normalizeHue(hue: number): number {
  if (isNaN(hue)) {
    return 0;
  }
  let value: number = hue % 360;
  if (value < 0) {
    value += 360;
  }
  return value;
}

/** HSL 的通道插值 */
function hueToChannel(p: number, q: number, t: number): number {
  let value: number = t;
  if (value < 0) {
    value += 1;
  }
  if (value > 1) {
    value -= 1;
  }
  if (value < 1 / 6) {
    return p + (q - p) * 6 * value;
  }
  if (value < 1 / 2) {
    return q;
  }
  if (value < 2 / 3) {
    return p + (q - p) * (2 / 3 - value) * 6;
  }
  return p;
}

// ── CMYK ─────────────────────────────────────────────────────

/** CMYK 表示（0~100 的百分比，按最朴素的转换口径） */
export class NGFcmyk {
  readonly cyan: number;
  readonly magenta: number;
  readonly yellow: number;
  readonly black: number;

  constructor(cyan: number, magenta: number, yellow: number, black: number) {
    this.cyan = cyan;
    this.magenta = magenta;
    this.yellow = yellow;
    this.black = black;
  }
}

/** 颜色 → CMYK（朴素换算：不做黑版生成与色彩管理） */
export function toCmyk(color: NGFColor): NGFcmyk {
  const r: number = color.red / CHANNEL_MAX;
  const g: number = color.green / CHANNEL_MAX;
  const b: number = color.blue / CHANNEL_MAX;
  const k: number = 1 - Math.max(r, Math.max(g, b));
  // 纯黑：k=1 时下面的分母为 0，直接返回 0/0/0/100
  if (k >= 1) {
    return new NGFcmyk(0, 0, 0, 100);
  }
  const c: number = (1 - r - k) / (1 - k);
  const m: number = (1 - g - k) / (1 - k);
  const y: number = (1 - b - k) / (1 - k);
  return new NGFcmyk(
    Math.round(c * 100),
    Math.round(m * 100),
    Math.round(y * 100),
    Math.round(k * 100)
  );
}

// ── 解析 ─────────────────────────────────────────────────────

/** 解析失败的原因 */
/** 简写构造器：把「中文 / English」写成一行 */
function l10n(zh: string, en: string): NGFLocalizedText {
  return new NGFLocalizedText(zh, en);
}

export enum ColorParseFailure {
  EMPTY = 'empty',
  /** 整体写法认不出来 */
  UNKNOWN_FORMAT = 'unknown_format',
  /** 十六进制里出现 0-9 / A-F 之外的字符 */
  HEX_BAD_CHAR = 'hex_bad_char',
  /** rgb()/rgba() 缺少右括号 */
  RGB_MISSING_PAREN = 'rgb_missing_paren',
  /** rgb()/rgba() 参数个数不对 */
  RGB_ARITY = 'rgb_arity',
  /** 通道值不是 0-255 的数字或百分数 */
  CHANNEL_RANGE = 'channel_range',
  /** hsl()/hsla() 缺少右括号 */
  HSL_MISSING_PAREN = 'hsl_missing_paren',
  /** hsl()/hsla() 参数个数不对 */
  HSL_ARITY = 'hsl_arity',
  /** 色相不是数字 */
  BAD_HUE = 'bad_hue',
  /** 饱和度/亮度没写百分数 */
  HSL_PERCENT = 'hsl_percent',
  /** 颜色名不认识 */
  UNKNOWN_NAME = 'unknown_name'
}

/** 解析结果 */
export class ColorParseResult {
  readonly ok: boolean;
  readonly failure: ColorParseFailure;
  /** 资源文案的占位符参数（顺序须与资源文案里 %s 一致） */
  readonly args: Array<string>;
  readonly color: NGFColor | null;
  /**
   * 输入里是否**省略了**可选项（例如 #abc 而非 #aabbcc、rgb(1,2,3) 而非 rgba）。
   * 用于在结果里给出「这是简写」的提示，而不是当成用户写错。
   */
  readonly shorthand: boolean;
  /** 命中具名颜色时的名字 */
  readonly name: string;

  constructor(
    ok: boolean,
    failure: ColorParseFailure,
    args: Array<string>,
    color: NGFColor | null,
    shorthand: boolean,
    name: string
  ) {
    this.ok = ok;
    this.failure = failure;
    this.args = args;
    this.color = color;
    this.shorthand = shorthand;
    this.name = name;
  }

  static success(color: NGFColor, shorthand: boolean, name: string): ColorParseResult {
    return new ColorParseResult(true, ColorParseFailure.EMPTY, [], color, shorthand, name);
  }

  static fail(failure: ColorParseFailure, args: Array<string>): ColorParseResult {
    return new ColorParseResult(false, failure, args, null, false, '');
  }
}

/**
 * 解析颜色字符串。支持：
 * - \`#RGB\`、\`#RGBA\`、\`#RRGGBB\`、\`#RRGGBBAA\`（# 可省略）
 * - \`rgb(r,g,b)\`、\`rgba(r,g,b,a)\`（百分数写法也收）
 * - \`hsl(h,s%,l%)\`、\`hsla(...)\`
 * - 具名颜色（red、steelblue 等常用 CSS 名）
 */
export function parseColor(input: string): ColorParseResult {
  const trimmed: string = input.trim();
  if (trimmed.length === 0) {
    return ColorParseResult.fail(ColorParseFailure.EMPTY, []);
  }

  const lower: string = trimmed.toLowerCase();

  // rgb() / rgba()
  if (lower.indexOf('rgb') === 0) {
    return parseRgbFunction(trimmed);
  }
  // hsl() / hsla()
  if (lower.indexOf('hsl') === 0) {
    return parseHslFunction(trimmed);
  }
  // 具名颜色
  const named: NGFNamedColor | null = findNamedColor(lower);
  if (named !== null) {
    return ColorParseResult.success(NGFColor.of(named.red, named.green, named.blue), false, named.name);
  }
  // HEX（含省略 # 的纯十六进制）
  return parseHex(trimmed);
}

/** 解析 #RGB / #RGBA / #RRGGBB / #RRGGBBAA */
function parseHex(input: string): ColorParseResult {
  let hex: string = input.trim();
  if (hex.charAt(0) === '#') {
    hex = hex.substring(1);
  }
  // 去掉常见的分隔写法（#FF-00-00 这类不合法，但 #FF 00 00 也不收，只收连续写法）
  if (hex.length !== 3 && hex.length !== 4 && hex.length !== 6 && hex.length !== 8) {
    return ColorParseResult.fail(ColorParseFailure.UNKNOWN_FORMAT,
      []);
  }
  for (let i: number = 0; i < hex.length; i++) {
    if (hexDigitValue(hex.charAt(i)) < 0) {
      // 长度对但字符非法（例如 #GGGGGG）——与「长度不对」分开，
      // 因为「你多写了一位」和「你写了 G」该给的提示完全不同。
      return ColorParseResult.fail(ColorParseFailure.HEX_BAD_CHAR, []);
    }
  }

  if (hex.length === 3 || hex.length === 4) {
    // 简写：每个字符重复一次
    const r: number = hexDigitValue(hex.charAt(0)) * 17;
    const g: number = hexDigitValue(hex.charAt(1)) * 17;
    const b: number = hexDigitValue(hex.charAt(2)) * 17;
    const a: number = hex.length === 4
      ? (hexDigitValue(hex.charAt(3)) * 17) / CHANNEL_MAX
      : 1;
    return ColorParseResult.success(new NGFColor(r, g, b, a, false), hex.length === 3, '');
  }

  const r: number = hexDigitValue(hex.charAt(0)) * 16 + hexDigitValue(hex.charAt(1));
  const g: number = hexDigitValue(hex.charAt(2)) * 16 + hexDigitValue(hex.charAt(3));
  const b: number = hexDigitValue(hex.charAt(4)) * 16 + hexDigitValue(hex.charAt(5));
  const a: number = hex.length === 8
    ? (hexDigitValue(hex.charAt(6)) * 16 + hexDigitValue(hex.charAt(7))) / CHANNEL_MAX
    : 1;
  return ColorParseResult.success(new NGFColor(r, g, b, a, false), false, '');
}

/** 取出函数式写法括号内的参数列表 */
function functionArguments(input: string): Array<string> | null {
  const open: number = input.indexOf('(');
  const close: number = input.lastIndexOf(')');
  if (open < 0 || close < 0 || close <= open) {
    return null;
  }
  const inner: string = input.substring(open + 1, close);
  const parts: Array<string> = inner.split(',');
  const result: Array<string> = [];
  for (let i: number = 0; i < parts.length; i++) {
    result.push(parts[i].trim());
  }
  return result;
}

/** 解析一个 0~255 的通道参数（支持百分数） */
function parseChannelArgument(text: string): number {
  if (text.length === 0) {
    return NaN;
  }
  if (text.charAt(text.length - 1) === '%') {
    const percent: number = parseFloat(text.substring(0, text.length - 1));
    if (isNaN(percent)) {
      return NaN;
    }
    return Math.round(percent * CHANNEL_MAX / 100);
  }
  const value: number = parseFloat(text);
  return isNaN(value) ? NaN : value;
}

/** 解析 alpha 参数（支持 0~1 与百分数） */
function parseAlphaArgument(text: string): number {
  if (text.length === 0) {
    return 1;
  }
  if (text.charAt(text.length - 1) === '%') {
    const percent: number = parseFloat(text.substring(0, text.length - 1));
    return isNaN(percent) ? 1 : percent / 100;
  }
  const value: number = parseFloat(text);
  return isNaN(value) ? 1 : value;
}

function parseRgbFunction(input: string): ColorParseResult {
  const args: Array<string> | null = functionArguments(input);
  if (args === null) {
    return ColorParseResult.fail(ColorParseFailure.RGB_MISSING_PAREN, []);
  }
  if (args.length !== 3 && args.length !== 4) {
    return ColorParseResult.fail(ColorParseFailure.RGB_ARITY, []);
  }
  const r: number = parseChannelArgument(args[0]);
  const g: number = parseChannelArgument(args[1]);
  const b: number = parseChannelArgument(args[2]);
  if (isNaN(r) || isNaN(g) || isNaN(b)) {
    return ColorParseResult.fail(ColorParseFailure.CHANNEL_RANGE,
      [String(0), String(CHANNEL_MAX)]);
  }
  const alpha: number = args.length === 4 ? parseAlphaArgument(args[3]) : 1;
  // 超出 0~255 会被夹紧并标记，界面据此提示
  const clamped: boolean = r < 0 || r > CHANNEL_MAX || g < 0 || g > CHANNEL_MAX
    || b < 0 || b > CHANNEL_MAX;
  return ColorParseResult.success(
    new NGFColor(clampChannel(r), clampChannel(g), clampChannel(b), clampRatio(alpha), clamped),
    args.length === 3,
    ''
  );
}

function parseHslFunction(input: string): ColorParseResult {
  const args: Array<string> | null = functionArguments(input);
  if (args === null) {
    return ColorParseResult.fail(ColorParseFailure.HSL_MISSING_PAREN, []);
  }
  if (args.length !== 3 && args.length !== 4) {
    return ColorParseResult.fail(ColorParseFailure.HSL_ARITY, []);
  }
  const hueText: string = args[0];
  const hue: number = parseFloat(hueText);
  if (isNaN(hue)) {
    return ColorParseResult.fail(ColorParseFailure.BAD_HUE,
      []);
  }
  const saturation: number = parsePercent(args[1]);
  const lightness: number = parsePercent(args[2]);
  if (isNaN(saturation) || isNaN(lightness)) {
    return ColorParseResult.fail(ColorParseFailure.HSL_PERCENT, []);
  }
  const alpha: number = args.length === 4 ? parseAlphaArgument(args[3]) : 1;
  const color: NGFColor = fromHsl(hue, saturation, lightness, alpha);
  return ColorParseResult.success(color, args.length === 3, '');
}

/** 解析 "93%" 或 "93" 形式的百分比 */
function parsePercent(text: string): number {
  if (text.length === 0) {
    return NaN;
  }
  const body: string = text.charAt(text.length - 1) === '%'
    ? text.substring(0, text.length - 1)
    : text;
  const value: number = parseFloat(body);
  return isNaN(value) ? NaN : value;
}

// ── 亮度与对比度 ─────────────────────────────────────────────

/**
 * 相对亮度（WCAG 定义）。
 *
 * **关键**：必须先做反 gamma（把 sRGB 编码值还原为线性光强）再加权。
 * 直接把编码值按 0.2126/0.7152/0.0722 加权是**错的**——
 * 那样算出来的对比度会偏大，会把不达标的配色判成达标，
 * 而对比度不达标正是无障碍问题里最常见、也最容易被工具掩盖的一种。
 */
export function relativeLuminance(color: NGFColor): number {
  const r: number = linearizeChannel(color.red / CHANNEL_MAX);
  const g: number = linearizeChannel(color.green / CHANNEL_MAX);
  const b: number = linearizeChannel(color.blue / CHANNEL_MAX);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/** 单个通道的反 gamma */
function linearizeChannel(value: number): number {
  const v: number = clampRatio(value);
  if (v <= 0.04045) {
    return v / 12.92;
  }
  return Math.pow((v + 0.055) / 1.055, 2.4);
}

/**
 * 两色的对比度（WCAG 口径，1~21）。
 *
 * 与顺序无关（内部会取亮者/暗者）。
 */
export function contrastRatio(first: NGFColor, second: NGFColor): number {
  const l1: number = relativeLuminance(first);
  const l2: number = relativeLuminance(second);
  const lighter: number = l1 >= l2 ? l1 : l2;
  const darker: number = l1 >= l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

/** WCAG 达标结论 */
export class NGFContrastVerdict {
  readonly ratio: number;
  /** 正文（小字）是否达到 AA（4.5:1） */
  readonly passesNormalAA: boolean;
  /** 大字号是否达到 AA（3:1） */
  readonly passesLargeAA: boolean;
  /** 是否达到 AAA 正文（7:1） */
  readonly passesNormalAAA: boolean;

  constructor(ratio: number, passesNormalAA: boolean, passesLargeAA: boolean, passesNormalAAA: boolean) {
    this.ratio = ratio;
    this.passesNormalAA = passesNormalAA;
    this.passesLargeAA = passesLargeAA;
    this.passesNormalAAA = passesNormalAAA;
  }
}

/** 评定对比度 */
export function evaluateContrast(foreground: NGFColor, background: NGFColor): NGFContrastVerdict {
  const ratio: number = contrastRatio(foreground, background);
  return new NGFContrastVerdict(
    ratio,
    ratio >= 4.5,
    ratio >= 3,
    ratio >= 7
  );
}

/**
 * 在一个背景色上，黑字与白字哪个更容易看清。
 *
 * 返回对比度更高的那个；用于给生成的颜色建议前景色。
 */
export function readableTextColor(background: NGFColor): NGFColor {
  const black: NGFColor = NGFColor.of(0, 0, 0);
  const white: NGFColor = NGFColor.of(255, 255, 255);
  return contrastRatio(black, background) >= contrastRatio(white, background) ? black : white;
}

// ── 派生颜色 ─────────────────────────────────────────────────

/** 按给定比例调亮/调暗（比例 -1~1，正数调亮） */
export function adjustLightness(color: NGFColor, amount: number): NGFColor {
  const hsl: NGFHsl = toHsl(color);
  const target: number = hsl.lightness + amount * 100;
  return fromHsl(hsl.hue, hsl.saturation, target, color.alpha);
}

/**
 * 生成同色相的一组明暗阶梯（常用于设计 Token 的 50~900 阶梯）。
 *
 * @param steps 阶梯数量；小于 1 时按 1 处理，避免返回空数组让调用方还要判空
 */
export function lightnessScale(color: NGFColor, steps: number): Array<NGFColor> {
  const count: number = steps < 1 ? 1 : Math.floor(steps);
  const hsl: NGFHsl = toHsl(color);
  const scale: Array<NGFColor> = [];
  if (count === 1) {
    scale.push(color);
    return scale;
  }
  for (let i: number = 0; i < count; i++) {
    // 从 8% 亮到 92% 亮均匀铺开：两端刻意不取 0/100，
    // 否则首尾会退化成纯黑纯白，失去色相信息。
    const lightness: number = 8 + (84 * i) / (count - 1);
    scale.push(fromHsl(hsl.hue, hsl.saturation, lightness, color.alpha));
  }
  return scale;
}

/** 色相旋转（用于生成互补色/三角配色） */
export function rotateHue(color: NGFColor, degrees: number): NGFColor {
  const hsl: NGFHsl = toHsl(color);
  return fromHsl(hsl.hue + degrees, hsl.saturation, hsl.lightness, color.alpha);
}

/**
 * 配色方案：互补、三角、四角、邻近。
 *
 * 返回的数组**含原色本身**（第一个），这样页面直接铺一排就能看全，
 * 不需要调用方自己再拼回去。
 */
export function harmony(color: NGFColor, kind: string): Array<NGFColor> {
  const result: Array<NGFColor> = [color];
  if (kind === 'complementary') {
    result.push(rotateHue(color, 180));
  } else if (kind === 'triadic') {
    result.push(rotateHue(color, 120));
    result.push(rotateHue(color, 240));
  } else if (kind === 'tetradic') {
    result.push(rotateHue(color, 90));
    result.push(rotateHue(color, 180));
    result.push(rotateHue(color, 270));
  } else if (kind === 'analogous') {
    result.push(rotateHue(color, -30));
    result.push(rotateHue(color, 30));
  }
  return result;
}

/** 可用的配色方案名与中文标签 */
export class NGFHarmonyOption {
  readonly kind: string;
  /** 方案名（双语数据，按 locale 取） */
  readonly label: NGFLocalizedText;

  constructor(kind: string, label: NGFLocalizedText) {
    this.kind = kind;
    this.label = label;
  }
}

export function harmonyOptions(): Array<NGFHarmonyOption> {
  const options: Array<NGFHarmonyOption> = [];
  // 名称是给人看的，做成双语（纯数据层带两种语言，见 NGFLocalizedText 的说明）
  options.push(new NGFHarmonyOption('complementary', l10n('互补', 'Complementary')));
  options.push(new NGFHarmonyOption('analogous', l10n('邻近', 'Analogous')));
  options.push(new NGFHarmonyOption('triadic', l10n('三角', 'Triadic')));
  options.push(new NGFHarmonyOption('tetradic', l10n('四角', 'Tetradic')));
  return options;
}

// ── 具名颜色 ─────────────────────────────────────────────────

/** 一个具名颜色 */
export class NGFNamedColor {
  readonly name: string;
  readonly red: number;
  readonly green: number;
  readonly blue: number;

  constructor(name: string, red: number, green: number, blue: number) {
    this.name = name;
    this.red = red;
    this.green = green;
    this.blue = blue;
  }
}

/**
 * 常用具名颜色。
 *
 * 刻意只收录**最常用的一批**而不是 CSS 全部 148 个：
 * 这是一本工具书式的速查表，全量收录会让页面变成一份需要搜索的清单，
 * 而用户更常做的是「我手上有 #0962F2，它像什么颜色」——
 * 那是 {@link nearestNamedColor} 的活儿。
 */
export function namedColors(): Array<NGFNamedColor> {
  const list: Array<NGFNamedColor> = [];
  list.push(new NGFNamedColor('black', 0, 0, 0));
  list.push(new NGFNamedColor('white', 255, 255, 255));
  list.push(new NGFNamedColor('red', 255, 0, 0));
  list.push(new NGFNamedColor('green', 0, 128, 0));
  list.push(new NGFNamedColor('lime', 0, 255, 0));
  list.push(new NGFNamedColor('blue', 0, 0, 255));
  list.push(new NGFNamedColor('yellow', 255, 255, 0));
  list.push(new NGFNamedColor('cyan', 0, 255, 255));
  list.push(new NGFNamedColor('magenta', 255, 0, 255));
  list.push(new NGFNamedColor('orange', 255, 165, 0));
  list.push(new NGFNamedColor('purple', 128, 0, 128));
  list.push(new NGFNamedColor('gray', 128, 128, 128));
  list.push(new NGFNamedColor('silver', 192, 192, 192));
  list.push(new NGFNamedColor('maroon', 128, 0, 0));
  list.push(new NGFNamedColor('olive', 128, 128, 0));
  list.push(new NGFNamedColor('navy', 0, 0, 128));
  list.push(new NGFNamedColor('teal', 0, 128, 128));
  list.push(new NGFNamedColor('pink', 255, 192, 203));
  list.push(new NGFNamedColor('brown', 165, 42, 42));
  list.push(new NGFNamedColor('steelblue', 70, 130, 180));
  list.push(new NGFNamedColor('skyblue', 135, 206, 235));
  list.push(new NGFNamedColor('coral', 255, 127, 80));
  list.push(new NGFNamedColor('gold', 255, 215, 0));
  list.push(new NGFNamedColor('crimson', 220, 20, 60));
  list.push(new NGFNamedColor('indigo', 75, 0, 130));
  list.push(new NGFNamedColor('turquoise', 64, 224, 208));
  list.push(new NGFNamedColor('salmon', 250, 128, 114));
  list.push(new NGFNamedColor('khaki', 240, 230, 140));
  list.push(new NGFNamedColor('plum', 221, 160, 221));
  list.push(new NGFNamedColor('orchid', 218, 112, 214));
  return list;
}

/** 按名字查；找不到返回 null */
export function findNamedColor(name: string): NGFNamedColor | null {
  const target: string = name.trim().toLowerCase();
  if (target.length === 0) {
    return null;
  }
  const list: Array<NGFNamedColor> = namedColors();
  for (let i: number = 0; i < list.length; i++) {
    if (list[i].name === target) {
      return list[i];
    }
  }
  return null;
}

/**
 * 找最接近的具名颜色。
 *
 * 距离用**加权 RGB**（人眼对绿色最敏感、蓝色最不敏感）而不是欧氏距离：
 * 用等权欧氏距离时，把深蓝错认成深紫的概率明显更高。
 */
export function nearestNamedColor(color: NGFColor): NGFNamedColor {
  const list: Array<NGFNamedColor> = namedColors();
  let best: NGFNamedColor = list[0];
  let bestDistance: number = Number.MAX_VALUE;
  for (let i: number = 0; i < list.length; i++) {
    const candidate: NGFNamedColor = list[i];
    bestDistance = bestDistance;
    const dr: number = color.red - candidate.red;
    const dg: number = color.green - candidate.green;
    const db: number = color.blue - candidate.blue;
    // 权重来自人眼锥细胞敏感度（红 0.299 / 绿 0.587 / 蓝 0.114 的常见近似）
    const distance: number = 0.299 * dr * dr + 0.587 * dg * dg + 0.114 * db * db;
    if (distance < bestDistance) {
      bestDistance = distance;
      best = candidate;
    }
  }
  return best;
}

// ── 汇总输出 ─────────────────────────────────────────────────

/** 一次转换的全部表示形式 */
export class NGFColorReport {
  readonly hex: string;
  readonly shortHex: string;
  readonly hexWithAlpha: string;
  readonly rgbText: string;
  readonly hslText: string;
  readonly hsvText: string;
  readonly cmykText: string;
  readonly nearestName: string;
  readonly readableText: string;
  readonly contrastOnWhite: number;
  readonly contrastOnBlack: number;

  constructor(
    hex: string,
    shortHex: string,
    hexWithAlpha: string,
    rgbText: string,
    hslText: string,
    hsvText: string,
    cmykText: string,
    nearestName: string,
    readableText: string,
    contrastOnWhite: number,
    contrastOnBlack: number
  ) {
    this.hex = hex;
    this.shortHex = shortHex;
    this.hexWithAlpha = hexWithAlpha;
    this.rgbText = rgbText;
    this.hslText = hslText;
    this.hsvText = hsvText;
    this.cmykText = cmykText;
    this.nearestName = nearestName;
    this.readableText = readableText;
    this.contrastOnWhite = contrastOnWhite;
    this.contrastOnBlack = contrastOnBlack;
  }
}

/** 生成全部表示形式 */
export function buildReport(color: NGFColor): NGFColorReport {
  const hsl: NGFHsl = toHsl(color);
  const hsv: NGFHsv = toHsv(color);
  const cmyk: NGFcmyk = toCmyk(color);
  const nearest: NGFNamedColor = nearestNamedColor(color);
  const white: NGFColor = NGFColor.of(255, 255, 255);
  const black: NGFColor = NGFColor.of(0, 0, 0);
  return new NGFColorReport(
    toHex(color),
    toShortHex(color),
    toHexWithAlpha(color),
    toRgbText(color),
    'hsl(' + String(hsl.hue) + ', ' + String(hsl.saturation) + '%, ' + String(hsl.lightness) + '%)',
    'hsv(' + String(hsv.hue) + ', ' + String(hsv.saturation) + '%, ' + String(hsv.value) + '%)',
    'cmyk(' + String(cmyk.cyan) + ', ' + String(cmyk.magenta) + ', ' + String(cmyk.yellow)
      + ', ' + String(cmyk.black) + ')',
    nearest.name,
    toHex(readableTextColor(color)),
    Math.round(contrastRatio(color, white) * 100) / 100,
    Math.round(contrastRatio(color, black) * 100) / 100
  );
}

/** 全部表示形式拼成的可复制文本 */
// formatColorText 已搬到 UI 层（ColorConvertMessages.ets）。
//
// 它产出的每一行都是「标签：值」——标签是文案，而纯逻辑层拿不到设备语言。
// 字段名（HEX / RGB / HSL 这些是缩写，两种语言一样）留在这里的 NGFColorReport 里，
// 中文标签（「最接近的颜色名」「建议前景色」）则归 UI 层。