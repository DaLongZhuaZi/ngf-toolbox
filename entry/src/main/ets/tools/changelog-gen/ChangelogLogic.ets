/**
 * Changelog 生成的纯逻辑实现（Conventional Commits 归类）。
 *
 * ## 语法
 *
 * type(scope): subject 或 type: subject。识别的类型：feat/fix/docs/style/refactor/
 * perf/test/build/ci/chore/revert。非规范行归入 Other。输出 Markdown 分节列表
 * （feat→Features、fix→Bug Fixes 等），feat/fix 排最前。
 *
 * @module tools/changelog-gen/ChangelogLogic
 */

/** 失败原因码 */
export enum ChangelogFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input'
}

/** 一次失败的原因与文案参数 */
export class ChangelogFailure {
  readonly code: ChangelogFailureCode;
  readonly args: Array<string>;

  constructor(code: ChangelogFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 归类结果 */
export class ChangelogResult {
  readonly ok: boolean;
  readonly failure: ChangelogFailure;
  readonly markdown: string;
  /** 参与归类的行数（不含 Other） */
  readonly classifiedCount: number;
  /** 未识别的行数 */
  readonly otherCount: number;

  constructor(ok: boolean, failure: ChangelogFailure, markdown: string,
    classifiedCount: number, otherCount: number) {
    this.ok = ok;
    this.failure = failure;
    this.markdown = markdown;
    this.classifiedCount = classifiedCount;
    this.otherCount = otherCount;
  }
}

const KNOWN_TYPES: Array<string> = ['feat', 'fix', 'docs', 'style', 'refactor',
  'perf', 'test', 'build', 'ci', 'chore', 'revert'];
const SECTION_NAMES: Array<string> = ['Features', 'Bug Fixes', 'Documentation',
  'Styles', 'Refactoring', 'Performance', 'Tests', 'Build', 'CI', 'Chore', 'Reverts'];
const NEWLINE: string = String.fromCharCode(10);
const SPACE: string = String.fromCharCode(32);

function sectionNameOfType(type: string): string {
  for (let i = 0; i < KNOWN_TYPES.length; i++) {
    if (KNOWN_TYPES[i] === type) {
      return SECTION_NAMES[i];
    }
  }
  return '';
}

/** 解析单行：返回 [type, cleaned subject]；不匹配返回 null */
function parseCommitLine(line: string): Array<string> | null {
  const t: string = line.trim();
  if (t.length === 0) {
    return null;
  }
  const colon: number = t.indexOf(':');
  if (colon < 0) {
    return null;
  }
  const head: string = t.substring(0, colon).trim();
  let subject: string = t.substring(colon + 1).trim();
  // scope 拆除（首尾圆括号）
  let type: string = head;
  const paren: number = head.indexOf('(');
  if (paren > 0 && head.charAt(head.length - 1) === ')') {
    type = head.substring(0, paren);
  }
  const lower: string = type.toLowerCase();
  let known: boolean = false;
  for (let i = 0; i < KNOWN_TYPES.length; i++) {
    if (KNOWN_TYPES[i] === lower) {
      known = true;
      break;
    }
  }
  if (!known) {
    return null;
  }
  if (subject.length > 0) {
    subject = subject.charAt(0).toUpperCase() + subject.substring(1);
  }
  const out: Array<string> = [lower, subject];
  return out;
}

/** 主入口 */
export function generateChangelog(input: string): ChangelogResult {
  if (input.trim().length === 0) {
    return new ChangelogResult(false, new ChangelogFailure(ChangelogFailureCode.EMPTY_INPUT, []), '', 0, 0);
  }
  const rawLines: Array<string> = input.split(NEWLINE);
  // type -> subject 列表
  const grouped: Map<string, Array<string>> = new Map<string, Array<string>>();
  let classified: number = 0;
  let other: number = 0;
  const others: Array<string> = [];
  for (let i = 0; i < rawLines.length; i++) {
    const parsed: Array<string> | null = parseCommitLine(rawLines[i]);
    if (parsed === null) {
      if (rawLines[i].trim().length > 0) {
        others.push(rawLines[i].trim());
        other++;
      }
      continue;
    }
    classified++;
    const type: string = parsed[0];
    if (!grouped.has(type)) {
      grouped.set(type, []);
    }
    const bucket: Array<string> | undefined = grouped.get(type);
    if (bucket !== undefined) {
      bucket.push(parsed[1]);
    }
  }
  const sections: Array<string> = [];
  for (let i = 0; i < KNOWN_TYPES.length; i++) {
    const type: string = KNOWN_TYPES[i];
    if (!grouped.has(type)) {
      continue;
    }
    const items: Array<string> | undefined = grouped.get(type);
    if (items === undefined) {
      continue;
    }
    let section: string = '### ' + SECTION_NAMES[i];
    for (let k = 0; k < items.length; k++) {
      section = section + NEWLINE + '- ' + items[k];
    }
    sections.push(section);
  }
  if (others.length > 0) {
    let section: string = '### Other';
    for (let k = 0; k < others.length; k++) {
      section = section + NEWLINE + '- ' + others[k];
    }
    sections.push(section);
  }
  return new ChangelogResult(true, new ChangelogFailure(ChangelogFailureCode.NONE, []),
    sections.join(NEWLINE + NEWLINE), classified, other);
}