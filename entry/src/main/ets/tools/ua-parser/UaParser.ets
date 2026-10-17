/**
 * User-Agent 解析的纯逻辑实现（启发式匹配）。
 *
 * ## 方法
 *
 * UA 字符串没有规范格式，只能**启发式**匹配：
 * - 浏览器：按特征子串匹配（Edg/ → Edge；OPR/ → Opera；Firefox；Chrome/Safari 顺序有讲究）
 * - 引擎：Blink（Chrome/Edge/Opera）、Gecko（Firefox）、WebKit（Safari）
 * - OS：Windows/macOS/Android/iOS/Linux 按特征子串
 *
 * ## 诚实边界（limitation 会写明）
 *
 * UA 可以伪造（开发者工具随意切换），启发式不保证完整——
 * 这是 UA 机制的固有限制，不是实现缺陷。返回「unknown」也是结果。
 *
 * @module tools/ua-parser/UaParser
 */

/** 解析结果 */
export class UaParseResult {
  readonly browser: string;
  readonly engine: string;
  readonly os: string;
  /** 无法识别时为 true（浏览器或 OS 至少一项 unknown） */
  readonly partial: boolean;

  constructor(browser: string, engine: string, os: string, partial: boolean) {
    this.browser = browser;
    this.engine = engine;
    this.os = os;
    this.partial = partial;
  }
}

function contains(haystack: string, needle: string): boolean {
  return haystack.indexOf(needle) >= 0;
}

/** 浏览器识别（顺序敏感：Edg 在 Chrome 之前） */
export function detectBrowser(ua: string): string {
  if (contains(ua, 'Edg/')) {
    return 'Edge';
  }
  if (contains(ua, 'OPR/') || contains(ua, 'Opera')) {
    return 'Opera';
  }
  if (contains(ua, 'Firefox/')) {
    return 'Firefox';
  }
  if (contains(ua, 'Chrome/')) {
    return 'Chrome';
  }
  if (contains(ua, 'Safari/')) {
    return 'Safari';
  }
  return 'unknown';
}

/** 引擎识别 */
export function detectEngine(ua: string): string {
  if (contains(ua, 'Edg/') || contains(ua, 'Chrome/') || contains(ua, 'OPR/')) {
    return 'Blink';
  }
  if (contains(ua, 'Gecko/')) {
    return 'Gecko';
  }
  if (contains(ua, 'AppleWebKit')) {
    return 'WebKit';
  }
  return 'unknown';
}

/** 操作系统识别 */
export function detectOS(ua: string): string {
  if (contains(ua, 'Windows NT')) {
    return 'Windows';
  }
  if (contains(ua, 'Android')) {
    return 'Android';
  }
  if (contains(ua, 'iPhone') || contains(ua, 'iPad')) {
    return 'iOS';
  }
  if (contains(ua, 'Mac OS X')) {
    return 'macOS';
  }
  if (contains(ua, 'Linux')) {
    return 'Linux';
  }
  return 'unknown';
}

/** 主入口 */
export function parseUserAgent(ua: string): UaParseResult {
  const browser: string = detectBrowser(ua);
  const engine: string = detectEngine(ua);
  const os: string = detectOS(ua);
  const partial: boolean = browser === 'unknown' || os === 'unknown';
  return new UaParseResult(browser, engine, os, partial);
}
