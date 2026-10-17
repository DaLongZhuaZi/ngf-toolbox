/**
 * SemVer 2.0.0 解析的纯逻辑实现。
 *
 * ## 语法
 *
 * 主.次.补丁[-先行版本][+构建元数据]。先行版本用点分隔的标识符（字母数字连字符），
 * 构建元数据在加号之后（不影响优先级）。支持 v 前缀容错。
 *
 * @module tools/semver-parse/SemverLogic
 */

/** 失败原因码 */
export enum SemverFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  BAD_FORMAT = 'bad_format'
}

/** 一次失败的原因与文案参数 */
export class SemverFailure {
  readonly code: SemverFailureCode;
  readonly args: Array<string>;

  constructor(code: SemverFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 解析结果 */
export class SemverInfo {
  readonly ok: boolean;
  readonly failure: SemverFailure;
  readonly major: number;
  readonly minor: number;
  readonly patch: number;
  readonly prerelease: string;
  readonly build: string;
  /** 规范化输出（无 v 前缀） */
  readonly normalized: string;

  constructor(ok: boolean, failure: SemverFailure, major: number, minor: number,
    patch: number, prerelease: string, build: string, normalized: string) {
    this.ok = ok;
    this.failure = failure;
    this.major = major;
    this.minor = minor;
    this.patch = patch;
    this.prerelease = prerelease;
    this.build = build;
    this.normalized = normalized;
  }
}

function isDigits(text: string): boolean {
  if (text.length === 0) {
    return false;
  }
  for (let i = 0; i < text.length; i++) {
    const ch: string = text.charAt(i);
    if (ch < '0' || ch > '9') {
      return false;
    }
  }
  return true;
}

/** 先行版本标识符合法性（字母数字连字符，点分隔） */
function validPrerelease(text: string): boolean {
  if (text.length === 0) {
    return false;
  }
  const parts: Array<string> = text.split('.');
  for (let i = 0; i < parts.length; i++) {
    const p: string = parts[i];
    if (p.length === 0) {
      return false;
    }
    for (let k = 0; k < p.length; k++) {
      const ch: string = p.charAt(k);
      const isLetter: boolean = (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z');
      const isNum: boolean = ch >= '0' && ch <= '9';
      if (!isLetter && !isNum && ch !== '-') {
        return false;
      }
    }
  }
  return true;
}

/** 主入口 */
export function parseSemver(input: string): SemverInfo {
  const fail = (): SemverInfo => new SemverInfo(false,
    new SemverFailure(SemverFailureCode.BAD_FORMAT, [input]), 0, 0, 0, '', '', '');
  if (input.trim().length === 0) {
    return new SemverInfo(false, new SemverFailure(SemverFailureCode.EMPTY_INPUT, []),
      0, 0, 0, '', '', '');
  }
  let text: string = input.trim();
  if (text.charAt(0) === 'v' || text.charAt(0) === 'V') {
    text = text.substring(1);
  }
  let build: string = '';
  const plus: number = text.indexOf('+');
  if (plus >= 0) {
    build = text.substring(plus + 1);
    text = text.substring(0, plus);
  }
  let prerelease: string = '';
  const dash: number = text.indexOf('-');
  if (dash >= 0) {
    prerelease = text.substring(dash + 1);
    text = text.substring(0, dash);
  }
  const parts: Array<string> = text.split('.');
  if (parts.length !== 3) {
    return fail();
  }
  if (!isDigits(parts[0]) || !isDigits(parts[1]) || !isDigits(parts[2])) {
    return fail();
  }
  if (prerelease.length > 0 && !validPrerelease(prerelease)) {
    return fail();
  }
  const major: number = parseInt(parts[0], 10);
  const minor: number = parseInt(parts[1], 10);
  const patch: number = parseInt(parts[2], 10);
  let normalized: string = parts[0] + '.' + parts[1] + '.' + parts[2];
  if (prerelease.length > 0) {
    normalized = normalized + '-' + prerelease;
  }
  return new SemverInfo(true, new SemverFailure(SemverFailureCode.NONE, []),
    major, minor, patch, prerelease, build, normalized);
}

/** 版本比较：负数/零/正数（含先行版本低于正式版的规则） */
export function compareSemver(a: SemverInfo, b: SemverInfo): number {
  if (a.major !== b.major) { return a.major < b.major ? -1 : 1; }
  if (a.minor !== b.minor) { return a.minor < b.minor ? -1 : 1; }
  if (a.patch !== b.patch) { return a.patch < b.patch ? -1 : 1; }
  if (a.prerelease.length === 0 && b.prerelease.length > 0) { return 1; }
  if (a.prerelease.length > 0 && b.prerelease.length === 0) { return -1; }
  if (a.prerelease === b.prerelease) { return 0; }
  const ap: Array<string> = a.prerelease.split('.');
  const bp: Array<string> = b.prerelease.split('.');
  const n: number = Math.min(ap.length, bp.length);
  for (let i = 0; i < n; i++) {
    const aNum: boolean = isDigits(ap[i]);
    const bNum: boolean = isDigits(bp[i]);
    if (aNum && bNum) {
      const av: number = parseInt(ap[i], 10);
      const bv: number = parseInt(bp[i], 10);
      if (av !== bv) { return av < bv ? -1 : 1; }
    } else if (aNum) {
      return -1;
    } else if (bNum) {
      return 1;
    } else if (ap[i] !== bp[i]) {
      return ap[i] < bp[i] ? -1 : 1;
    }
  }
  return ap.length === bp.length ? 0 : (ap.length < bp.length ? -1 : 1);
}