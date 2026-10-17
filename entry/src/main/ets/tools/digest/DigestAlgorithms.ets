/**
 * 摘要计算的对外纯逻辑 API。
 *
 * ## 分层
 *
 * 本文件只做「把字符串变成摘要」和「比对两份指纹」这两件事，不碰任何 UI 与设备能力：
 * - 算法实现在 {@link ./HashCore}（同样无依赖）；
 * - 页面在 `DigestPage.ets`，它负责输入、展示、复制与调用框架能力做交叉校验。
 *
 * 这样切的收益很直接：摘要值与指纹比对规则是用户可感知的正确性，
 * 必须能在 `entry/src/test` 里被真实单测覆盖，而不是等到真机上才发现算错。
 *
 * @module tools/digest/DigestAlgorithms
 */

import { md5HexOfBytes, sha1HexOfBytes, sha256HexOfBytes, sha512HexOfBytes, utf8Encode } from './HashCore';

/**
 * 支持的摘要算法。
 *
 * 枚举值是**用户可见的展示名**（'SHA-1' 这种带连字符的写法是各处的通用叫法），
 * 所以不做二次映射——多一层映射就多一个「界面显示 SHA1、文档写 SHA-1」的不一致来源。
 */
export enum NGFDigestAlgorithm {
  /** 128 位。只适合做「文件有没有传坏」的完整性比对，不可用于安全校验 */
  MD5 = 'MD5',
  /** 160 位。同样已被证明可以构造碰撞，只做一致性比对 */
  SHA1 = 'SHA-1',
  /** 256 位。当前的通用推荐值 */
  SHA256 = 'SHA-256',
  /** 512 位。输出更长、计算更慢，安全性不比 SHA-256 更高 */
  SHA512 = 'SHA-512'
}

/** 一条摘要结果：算法 + 摘要值 + 便于阅读的分组形式 */
export class NGFDigestResult {
  readonly algorithm: NGFDigestAlgorithm;
  /** 展示名（'MD5' / 'SHA-1' / 'SHA-256' / 'SHA-512'） */
  readonly label: string;
  /** 小写十六进制摘要 */
  readonly hex: string;
  /** 每 8 个字符一组，长摘要肉眼比对时更容易定位到差异位置 */
  readonly grouped: string;

  constructor(algorithm: NGFDigestAlgorithm, hex: string) {
    this.algorithm = algorithm;
    this.label = algorithmLabel(algorithm);
    this.hex = hex;
    this.grouped = groupHex(hex, 8);
  }
}

/**
 * 指纹比对结论码。
 *
 * 纯逻辑不产出面向用户的句子：本模块不能 import ArkUI 的 \`$r()\`，
 * 因此没有能力按设备语言选文案。它只回答「结论是什么、文案需要哪些参数」，
 * 由 UI 层（\`DigestMessages.ets\`）翻译成人话。
 */
export enum DigestCompareCode {
  /** 期望值没填 */
  EMPTY_EXPECTED = 'empty_expected',
  /** 期望值里有非十六进制字符 */
  NON_HEX = 'non_hex',
  /** 还没算出摘要，没得比 */
  NO_ACTUAL = 'no_actual',
  /** 两边长度不同（多半是算法选错了） */
  LENGTH_MISMATCH = 'length_mismatch',
  /** 一致 */
  MATCH = 'match',
  /** 不一致 */
  MISMATCH = 'mismatch'
}

/** 结论码 + 资源文案的占位符参数（顺序须与资源文案里 %s 一致） */
export class DigestCompareOutcome {
  readonly code: DigestCompareCode;
  readonly args: Array<string>;

  constructor(code: DigestCompareCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 指纹比对的结果：不只回答「一样不一样」，还要能解释「为什么不能比」 */
export class NGFFingerprintCompareResult {
  /** 两份指纹是否完全一致（只有两边都合法且等长时才可能为 true） */
  readonly matched: boolean;
  /** 归一化后的期望值（去掉分隔符并小写） */
  readonly expectedNormalized: string;
  /** 归一化后的实际值 */
  readonly actualNormalized: string;
  /** 期望值本身是否是一段合法的十六进制指纹 */
  readonly expectedValid: boolean;
  /** 结论码与参数；文案由 UI 层翻译 */
  readonly outcome: DigestCompareOutcome;

  constructor(matched: boolean, expectedNormalized: string, actualNormalized: string,
    expectedValid: boolean, outcome: DigestCompareOutcome) {
    this.matched = matched;
    this.expectedNormalized = expectedNormalized;
    this.actualNormalized = actualNormalized;
    this.expectedValid = expectedValid;
    this.outcome = outcome;
  }
}

/** 算法展示名；未知算法返回空串（界面据此判断「这条结果不该显示」） */
export function algorithmLabel(algorithm: NGFDigestAlgorithm): string {
  if (algorithm === NGFDigestAlgorithm.MD5) {
    return 'MD5';
  }
  if (algorithm === NGFDigestAlgorithm.SHA1) {
    return 'SHA-1';
  }
  if (algorithm === NGFDigestAlgorithm.SHA256) {
    return 'SHA-256';
  }
  if (algorithm === NGFDigestAlgorithm.SHA512) {
    return 'SHA-512';
  }
  return '';
}

/** 界面展示顺序：短到长，从「最快但不安全」到「最慢但最长」 */
export function digestAlgorithms(): NGFDigestAlgorithm[] {
  const ordered: NGFDigestAlgorithm[] = [
    NGFDigestAlgorithm.MD5,
    NGFDigestAlgorithm.SHA1,
    NGFDigestAlgorithm.SHA256,
    NGFDigestAlgorithm.SHA512
  ];
  return ordered;
}

/**
 * 按展示名计算摘要。
 *
 * 为什么要有一个按字符串取摘要的入口：界面上算法是用字符串传的（列表项、草稿、
 * 将来的历史记录），而「用户传了个不认识的算法名」必须能被单测覆盖——
 * 传枚举就构造不出这种输入了。未知名称返回空串而不是抛异常：
 * 摘要工具不该因为一个算法名拼错就整页崩掉。
 */
export function digestHexByLabel(label: string, text: string): string {
  const bytes: Uint8Array = utf8Encode(text);
  if (label === NGFDigestAlgorithm.MD5) {
    return md5HexOfBytes(bytes);
  }
  if (label === NGFDigestAlgorithm.SHA1) {
    return sha1HexOfBytes(bytes);
  }
  if (label === NGFDigestAlgorithm.SHA256) {
    return sha256HexOfBytes(bytes);
  }
  if (label === NGFDigestAlgorithm.SHA512) {
    return sha512HexOfBytes(bytes);
  }
  return '';
}

/** 计算单个算法的摘要，返回小写十六进制 */
export function digestHexOfText(algorithm: NGFDigestAlgorithm, text: string): string {
  return digestHexByLabel(algorithmLabel(algorithm), text);
}

/** 计算单个算法并打包成结果对象 */
export function digestOfText(algorithm: NGFDigestAlgorithm, text: string): NGFDigestResult {
  return new NGFDigestResult(algorithm, digestHexOfText(algorithm, text));
}

/**
 * 一次算出四种摘要。
 *
 * 文本只做一次 UTF-8 编码再喂给四个算法：编码是整个流程里唯一可能出错的
 * 字符集环节，共用一个字节数组可以保证四个结果口径完全一致。
 */
export function digestAllOfText(text: string): NGFDigestResult[] {
  const bytes: Uint8Array = utf8Encode(text);
  const results: NGFDigestResult[] = [];
  results.push(new NGFDigestResult(NGFDigestAlgorithm.MD5, md5HexOfBytes(bytes)));
  results.push(new NGFDigestResult(NGFDigestAlgorithm.SHA1, sha1HexOfBytes(bytes)));
  results.push(new NGFDigestResult(NGFDigestAlgorithm.SHA256, sha256HexOfBytes(bytes)));
  results.push(new NGFDigestResult(NGFDigestAlgorithm.SHA512, sha512HexOfBytes(bytes)));
  return results;
}

/**
 * 归一化一段指纹文本。
 *
 * 用户拿到的摘要有各种写法：`d41d8cd9 8f00b204`、`D41D8CD9:8F00B204`、
 * `md5: d41d8cd98f00b204e9800998ecf8427e`（这里只保留十六进制部分）。
 * 归一化只做两件事：去掉分隔符与空白、统一小写——**不**做任何猜测性修正，
 * 免得把「用户粘错了」变成「工具说一样」。
 */
export function normalizeFingerprint(value: string): string {
  const text: string = value.trim().toLowerCase();
  let normalized: string = '';
  for (let i: number = 0; i < text.length; i++) {
    const ch: string = text.charAt(i);
    if (ch === ' ' || ch === '\t' || ch === '\n' || ch === '\r' || ch === ':' || ch === '-') {
      continue;
    }
    normalized += ch;
  }
  if (normalized.length > 2 && normalized.substring(0, 2) === '0x') {
    normalized = normalized.substring(2);
  }
  return normalized;
}

/** 归一化后的文本是否为合法的十六进制指纹（空串不算合法） */
export function isHexFingerprint(value: string): boolean {
  if (value.length === 0) {
    return false;
  }
  for (let i: number = 0; i < value.length; i++) {
    const code: number = value.charCodeAt(i);
    const isDigit: boolean = code >= 48 && code <= 57;
    const isLowerHex: boolean = code >= 97 && code <= 102;
    if (!isDigit && !isLowerHex) {
      return false;
    }
  }
  return true;
}

/** 把摘要按固定长度分组展示；groupSize 非法时原样返回 */
export function groupHex(hex: string, groupSize: number): string {
  if (groupSize <= 0 || hex.length <= groupSize) {
    return hex;
  }
  let grouped: string = '';
  for (let i: number = 0; i < hex.length; i += groupSize) {
    if (i > 0) {
      grouped += ' ';
    }
    const end: number = i + groupSize < hex.length ? i + groupSize : hex.length;
    grouped += hex.substring(i, end);
  }
  return grouped;
}

/**
 * 比对两份指纹。
 *
 * 「比不了」和「不一样」是两件事：前者要告诉用户去改输入，后者才是结论。
 * 所以返回的是带**结论码**的结果对象，而不是一个 boolean——
 * 界面只负责把码翻成文案，不需要自己判断语义（也不需要判空）。
 */
export function compareFingerprint(expected: string, actual: string): NGFFingerprintCompareResult {
  const expectedNormalized: string = normalizeFingerprint(expected);
  const actualNormalized: string = normalizeFingerprint(actual);
  if (expectedNormalized.length === 0) {
    return new NGFFingerprintCompareResult(false, expectedNormalized, actualNormalized, false,
      new DigestCompareOutcome(DigestCompareCode.EMPTY_EXPECTED, []));
  }
  if (!isHexFingerprint(expectedNormalized)) {
    return new NGFFingerprintCompareResult(false, expectedNormalized, actualNormalized, false,
      new DigestCompareOutcome(DigestCompareCode.NON_HEX, []));
  }
  if (actualNormalized.length === 0) {
    return new NGFFingerprintCompareResult(false, expectedNormalized, actualNormalized, true,
      new DigestCompareOutcome(DigestCompareCode.NO_ACTUAL, []));
  }
  if (expectedNormalized.length !== actualNormalized.length) {
    return new NGFFingerprintCompareResult(false, expectedNormalized, actualNormalized, true,
      new DigestCompareOutcome(DigestCompareCode.LENGTH_MISMATCH,
        [String(expectedNormalized.length), String(actualNormalized.length)]));
  }
  if (expectedNormalized === actualNormalized) {
    return new NGFFingerprintCompareResult(true, expectedNormalized, actualNormalized, true,
      new DigestCompareOutcome(DigestCompareCode.MATCH, []));
  }
  return new NGFFingerprintCompareResult(false, expectedNormalized, actualNormalized, true,
    new DigestCompareOutcome(DigestCompareCode.MISMATCH, []));
}
