/**
 * Markdown 链接检查的纯逻辑实现。
 *
 * ## 功能
 *
 * 提取 [text](target) 与 ![alt](src) 两类链接，分类：锚点（#开头）、相对路径、
 * 绝对 URL（http/https）、其它协议（mailto: 等）；重复 target 检测（常见笔误）；
 * 空文本/空 target 检测。不发网络请求——纯文本检查。
 *
 * @module tools/md-link-check/MdLinkCheckLogic
 */
/** 失败原因码 */
export enum MdLinkFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input'
}

/** 一次失败的原因与文案参数 */
export class MdLinkFailure {
  readonly code: MdLinkFailureCode;
  readonly args: Array<string>;

  constructor(code: MdLinkFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 链接分类 */
export enum MdLinkKind {
  ANCHOR = 'anchor',
  RELATIVE = 'relative',
  ABSOLUTE = 'absolute',
  OTHER_PROTOCOL = 'other'
}
/** 一条链接 */
export class MdLinkItem {
  readonly text: string;
  readonly target: string;
  readonly kind: MdLinkKind;
  readonly isImage: boolean;
  readonly line: number;

  constructor(text: string, target: string, kind: MdLinkKind, isImage: boolean, line: number) {
    this.text = text;
    this.target = target;
    this.kind = kind;
    this.isImage = isImage;
    this.line = line;
  }
}

/** 检查结果 */
export class MdLinkCheckResult {
  readonly ok: boolean;
  readonly failure: MdLinkFailure;
  readonly links: Array<MdLinkItem>;
  /** 重复 target 清单 */
  readonly duplicates: Array<string>;
  /** 空 target 的数量 */
  readonly emptyTargets: number;

  constructor(ok: boolean, failure: MdLinkFailure, links: Array<MdLinkItem>,
    duplicates: Array<string>, emptyTargets: number) {
    this.ok = ok;
    this.failure = failure;
    this.links = links;
    this.duplicates = duplicates;
    this.emptyTargets = emptyTargets;
  }
}
function classifyTarget(target: string): MdLinkKind {
  if (target.charAt(0) === String.fromCharCode(35)) {
    return MdLinkKind.ANCHOR;
  }
  if (target.indexOf('http://') === 0 || target.indexOf('https://') === 0) {
    return MdLinkKind.ABSOLUTE;
  }
  const proto: number = target.indexOf(':');
  if (proto > 0 && proto < 8) {
    return MdLinkKind.OTHER_PROTOCOL;
  }
  return MdLinkKind.RELATIVE;
}

/** 主入口 */
export function checkLinks(input: string): MdLinkCheckResult {
  if (input.trim().length === 0) {
    return new MdLinkCheckResult(false, new MdLinkFailure(MdLinkFailureCode.EMPTY_INPUT, []), [], [], 0);
  }
  const links: Array<MdLinkItem> = [];
  const seenTargets: Map<string, number> = new Map<string, number>();
  const duplicates: Array<string> = [];
  let emptyTargets: number = 0;
  const rawLines: Array<string> = input.split(String.fromCharCode(10));
  for (let li = 0; li < rawLines.length; li++) {
    const line: string = rawLines[li];
    let cursor: number = 0;
    while (cursor < line.length) {
      const open: number = line.indexOf('[', cursor);
      if (open < 0) { break; }
      const close: number = line.indexOf(']', open + 1);
      if (close < 0) { break; }
      const paren: number = line.indexOf('(', close + 1);
      if (paren !== close + 1) { cursor = open + 1; continue; }
      const parenClose: number = line.indexOf(')', paren + 1);
      if (parenClose < 0) { break; }
      let isImage: boolean = false;
      let textStart: number = open + 1;
      if (open > 0 && line.charAt(open - 1) === String.fromCharCode(33)) {
        isImage = true;
        textStart = open;
      }
      const text: string = line.substring(textStart, close);
      const target: string = line.substring(paren + 1, parenClose);
      if (target.trim().length === 0) {
        emptyTargets++;
      }      const kind: MdLinkKind = classifyTarget(target);
      links.push(new MdLinkItem(text, target, kind, isImage, li + 1));
      if (seenTargets.has(target)) {
        if (duplicates.indexOf(target) < 0) {
          duplicates.push(target);
        }
      } else {
        seenTargets.set(target, 1);
      }
      cursor = parenClose + 1;
    }
  }
  return new MdLinkCheckResult(true, new MdLinkFailure(MdLinkFailureCode.NONE, []),
    links, duplicates, emptyTargets);
}