/**
 * 文本哈希校验的纯逻辑实现（薄封装 HashCore 的多算法）。
 *
 * ## 本工具的增量
 *
 * 一次输入同时输出 MD5/SHA-1/SHA-256/SHA-512 四个哈希（发布校验场景常需要
 * 「无论发布方给的是哪个算法都能对上」）；外加与给定校验值的比对判定
 * （大小写不敏感、自动去空格与 0x 前缀）。
 *
 * @module tools/file-hash/FileHashLogic
 */

import {
  md5HexOfBytes,
  sha1HexOfBytes,
  sha256HexOfBytes,
  sha512HexOfBytes,
  utf8Encode
} from '../digest/HashCore';

/** 失败原因码 */
export enum FileHashFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input'
}

/** 一次失败的原因与文案参数 */
export class FileHashFailure {
  readonly code: FileHashFailureCode;
  readonly args: Array<string>;

  constructor(code: FileHashFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 多算法哈希结果 */
export class FileHashResult {
  readonly ok: boolean;
  readonly failure: FileHashFailure;
  readonly md5: string;
  readonly sha1: string;
  readonly sha256: string;
  readonly sha512: string;
  /** 与期望值比对：空 = 未提供，match = 匹配，mismatch = 不匹配 */
  readonly compareOutcome: string;
  /** 与哪个算法的值匹配（compareOutcome=match 时有值） */
  readonly matchedAlgorithm: string;

  constructor(ok: boolean, failure: FileHashFailure, md5: string, sha1: string,
    sha256: string, sha512: string, compareOutcome: string, matchedAlgorithm: string) {
    this.ok = ok;
    this.failure = failure;
    this.md5 = md5;
    this.sha1 = sha1;
    this.sha256 = sha256;
    this.sha512 = sha512;
    this.compareOutcome = compareOutcome;
    this.matchedAlgorithm = matchedAlgorithm;
  }
}

/** 规范化期望值：去空格、去 0x 前缀、小写 */
export function normalizeExpected(raw: string): string {
  let t: string = raw.trim().toLowerCase();
  if (t.indexOf('0x') === 0) {
    t = t.substring(2);
  }
  let out: string = '';
  for (let i = 0; i < t.length; i++) {
    const ch: string = t.charAt(i);
    if (ch !== ' ' && ch !== String.fromCharCode(9)) {
      out = out + ch;
    }
  }
  return out;
}

/** 主入口 */
export function hashWithCompare(text: string, expected: string): FileHashResult {
  if (text.length === 0) {
    return new FileHashResult(false, new FileHashFailure(FileHashFailureCode.EMPTY_INPUT, []),
      '', '', '', '', '', '');
  }
  const bytes: Uint8Array = utf8Encode(text);
  const md5: string = md5HexOfBytes(bytes);
  const sha1: string = sha1HexOfBytes(bytes);
  const sha256: string = sha256HexOfBytes(bytes);
  const sha512: string = sha512HexOfBytes(bytes);
  const expectedNorm: string = normalizeExpected(expected);
  let outcome: string = '';
  let matched: string = '';
  if (expectedNorm.length > 0) {
    outcome = 'mismatch';
    if (expectedNorm === md5) {
      outcome = 'match';
      matched = 'MD5';
    } else if (expectedNorm === sha1) {
      outcome = 'match';
      matched = 'SHA-1';
    } else if (expectedNorm === sha256) {
      outcome = 'match';
      matched = 'SHA-256';
    } else if (expectedNorm === sha512) {
      outcome = 'match';
      matched = 'SHA-512';
    }
  }
  return new FileHashResult(true, new FileHashFailure(FileHashFailureCode.NONE, []),
    md5, sha1, sha256, sha512, outcome, matched);
}