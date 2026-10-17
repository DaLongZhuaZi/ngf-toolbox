/**
 * HTML 实体编解码的纯逻辑实现。
 *
 * ## 三类实体
 *
 * 1. 命名实体：&amp; &lt; &gt; &quot; &apos; &nbsp; &copy; 等（内置常用表）；
 * 2. 十进制数字实体：&#38; → &；
 * 3. 十六进制实体：&#x26; / &#X26; → &。
 *
 * ## 编码策略
 *
 * 默认只编码 HTML 保留的五个字符（& < > " '）——这是「放进 HTML 里不会破坏结构」
 * 的最小集合。可选「扩展模式」把非 ASCII 字符也编成数字实体（用于把中文塞进
 * 只认 ASCII 的旧系统）。解码总是三类都认。
 *
 * ## 转义说明（写这个文件时的实际坑）
 *
 * 本文件所有「字符」一律用 String.fromCharCode 表达，不写反斜杠转义——
 * 模板写入器会把它们写成字面文本（第三次踩坑的教训，见上一轮）。
 *
 * @module tools/html-entity/HtmlEntity
 */

/** 失败原因码 */
export enum HtmlEntityFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  /** 未知命名实体：&notARealOne; */
  UNKNOWN_NAMED = 'unknown_named',
  /** 数字实体超出 Unicode 范围：&#x110000; */
  CODE_POINT_OUT_OF_RANGE = 'code_point_out_of_range',
  /** 实体没有分号结尾：&amp（浏览器宽容，这里报错不猜） */
  MISSING_SEMICOLON = 'missing_semicolon'
}

/** 一次失败的原因与文案参数 */
export class HtmlEntityFailure {
  readonly code: HtmlEntityFailureCode;
  readonly args: Array<string>;

  constructor(code: HtmlEntityFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 解码结果 */
export class HtmlEntityDecodeResult {
  readonly ok: boolean;
  readonly failure: HtmlEntityFailure;
  readonly text: string;
  /** 替换次数（统计展示用） */
  readonly replaced: number;

  constructor(ok: boolean, failure: HtmlEntityFailure, text: string, replaced: number) {
    this.ok = ok;
    this.failure = failure;
    this.text = text;
    this.replaced = replaced;
  }
}

function amp(): string {
  return String.fromCharCode(38);
}

function semicolon(): string {
  return String.fromCharCode(59);
}

function hash(): string {
  return String.fromCharCode(35);
}

function lowerX(): string {
  return String.fromCharCode(120);
}

/**
 * 常用命名实体表：两个平行数组（键不含 & 与分号），小写存储。
 *
 * ## 为什么不用 Map + IIFE
 *
 * 第一版用「立即执行函数填充 Map」——Node 单测通过，hypium 运行器里
 * Map 是空的（初始化时序差异），表现为「AMP; 解不出、表规模为 0」。
 * 平行数组 + 模块级常量在两个运行器里行为完全一致，40 项线性查找也够快。
 */
const NAMED_KEYS: Array<string> = [
  'amp', 'lt', 'gt', 'quot', 'apos', 'nbsp', 'copy', 'reg', 'trade', 'hellip',
  'mdash', 'ndash', 'laquo', 'raquo', 'times', 'divide', 'deg', 'plusmn', 'middot', 'bull',
  'sect', 'para', 'euro', 'pound', 'yen', 'cent', 'larr', 'uarr', 'rarr', 'darr',
  'harr', 'ne', 'le', 'ge', 'alpha', 'beta', 'gamma', 'omega', 'infin'
];
const NAMED_VALUES: Array<string> = [
  String.fromCharCode(38), String.fromCharCode(60), String.fromCharCode(62), String.fromCharCode(34), String.fromCharCode(39), String.fromCharCode(160), String.fromCharCode(169), String.fromCharCode(174), String.fromCharCode(8482), String.fromCharCode(8230),
  String.fromCharCode(8212), String.fromCharCode(8211), String.fromCharCode(171), String.fromCharCode(187), String.fromCharCode(215), String.fromCharCode(247), String.fromCharCode(176), String.fromCharCode(177), String.fromCharCode(183), String.fromCharCode(8226),
  String.fromCharCode(167), String.fromCharCode(182), String.fromCharCode(8364), String.fromCharCode(163), String.fromCharCode(165), String.fromCharCode(162), String.fromCharCode(8592), String.fromCharCode(8593), String.fromCharCode(8594), String.fromCharCode(8595),
  String.fromCharCode(8596), String.fromCharCode(8800), String.fromCharCode(8804), String.fromCharCode(8805), String.fromCharCode(945), String.fromCharCode(946), String.fromCharCode(947), String.fromCharCode(969), String.fromCharCode(8734)
];

/** 查命名实体（大小写不敏感）；未命中返回空串 */
export function lookupNamedEntity(key: string): string {
  const lower: string = key.toLowerCase();
  for (let i = 0; i < NAMED_KEYS.length; i++) {
    if (NAMED_KEYS[i] === lower) {
      return NAMED_VALUES[i];
    }
  }
  return '';
}

/**
 * 编码用的保留字符：字符 → 实体名（不含 & 与分号）。
 * 与命名表同理用平行判断，不用 Map+IIFE（hypium 初始化时序坑）。
 */
function reservedName(ch: string): string {
  if (ch === String.fromCharCode(38)) {
    return 'amp';
  }
  if (ch === String.fromCharCode(60)) {
    return 'lt';
  }
  if (ch === String.fromCharCode(62)) {
    return 'gt';
  }
  if (ch === String.fromCharCode(34)) {
    return 'quot';
  }
  if (ch === String.fromCharCode(39)) {
    return 'apos';
  }
  return '';
}

/**
 * 解码 HTML 实体。
 *
 * 命名实体大小写不敏感（&AMP; 与 &amp; 同）。遇到未知命名实体/越界码点/
 * 缺分号时**报错**（不浏览器式宽容——本工具的价值是精确，宽容会把问题藏起来）。
 */
export function decodeHtmlEntities(input: string): HtmlEntityDecodeResult {
  if (input.trim().length === 0) {
    return new HtmlEntityDecodeResult(false,
      new HtmlEntityFailure(HtmlEntityFailureCode.EMPTY_INPUT, []), '', 0);
  }
  const text: string = input;
  let out: string = '';
  let replaced: number = 0;
  let i: number = 0;
  while (i < text.length) {
    const ch: string = text.charAt(i);
    if (ch !== amp()) {
      out = out + ch;
      i++;
      continue;
    }
    // 找分号
    const semi: number = text.indexOf(semicolon(), i);
    if (semi < 0) {
      return new HtmlEntityDecodeResult(false,
        new HtmlEntityFailure(HtmlEntityFailureCode.MISSING_SEMICOLON, []), '', replaced);
    }
    const body: string = text.substring(i + 1, semi);
    if (body.length === 0) {
      return new HtmlEntityDecodeResult(false,
        new HtmlEntityFailure(HtmlEntityFailureCode.MISSING_SEMICOLON, []), '', replaced);
    }
    if (body.charAt(0) === hash()) {
      // 数字实体
      const numBody: string = body.substring(1);
      if (numBody.length === 0) {
        return new HtmlEntityDecodeResult(false,
          new HtmlEntityFailure(HtmlEntityFailureCode.MISSING_SEMICOLON, []), '', replaced);
      }
      let isHex: boolean = false;
      let digits: string = numBody;
      if (numBody.charAt(0) === lowerX() || numBody.charAt(0) === String.fromCharCode(88)) {
        isHex = true;
        digits = numBody.substring(1);
      }
      if (digits.length === 0) {
        return new HtmlEntityDecodeResult(false,
          new HtmlEntityFailure(HtmlEntityFailureCode.MISSING_SEMICOLON, []), '', replaced);
      }
      let value: number = 0;
      for (let d = 0; d < digits.length; d++) {
        const dc: string = digits.charAt(d);
        let v: number = -1;
        if (dc >= '0' && dc <= '9') {
          v = dc.charCodeAt(0) - 48;
        } else if (isHex && dc >= 'a' && dc <= 'f') {
          v = dc.charCodeAt(0) - 87;
        } else if (isHex && dc >= 'A' && dc <= 'F') {
          v = dc.charCodeAt(0) - 55;
        }
        if (v < 0) {
          return new HtmlEntityDecodeResult(false,
            new HtmlEntityFailure(HtmlEntityFailureCode.MISSING_SEMICOLON, []), '', replaced);
        }
        value = value * (isHex ? 16 : 10) + v;
        if (value > 1114111) {
          return new HtmlEntityDecodeResult(false,
            new HtmlEntityFailure(HtmlEntityFailureCode.CODE_POINT_OUT_OF_RANGE, [digits]), '', replaced);
        }
      }
      try {
        out = out + String.fromCodePoint(value);
      } catch (e) {
        return new HtmlEntityDecodeResult(false,
          new HtmlEntityFailure(HtmlEntityFailureCode.CODE_POINT_OUT_OF_RANGE, [digits]), '', replaced);
      }
      replaced++;
      i = semi + 1;
      continue;
    }
    // 命名实体（大小写不敏感）
    const value: string = lookupNamedEntity(body);
    if (value.length === 0) {
      return new HtmlEntityDecodeResult(false,
        new HtmlEntityFailure(HtmlEntityFailureCode.UNKNOWN_NAMED, [amp() + body + semicolon()]), '', replaced);
    }
    out = out + value;
    replaced++;
    i = semi + 1;
  }
  return new HtmlEntityDecodeResult(true,
    new HtmlEntityFailure(HtmlEntityFailureCode.NONE, []), out, replaced);
}

/**
 * 编码 HTML 实体。
 * 默认只编码五个保留字符；extended=true 时非 ASCII 全部编成十进制数字实体。
 */
export function encodeHtmlEntities(input: string, extended: boolean): string {
  let out: string = '';
  for (let i = 0; i < input.length; i++) {
    const ch: string = input.charAt(i);
    const name: string = reservedName(ch);
    if (name.length > 0) {
      out = out + amp() + name + semicolon();
      continue;
    }
    const code: number = ch.charCodeAt(0);
    if (extended && code > 126) {
      out = out + amp() + hash() + String(code) + semicolon();
      continue;
    }
    out = out + ch;
  }
  return out;
}

/** 内置命名实体表的键数（关于页/README 可引用） */
export function namedEntityCount(): number {
  return NAMED_KEYS.length;
}
