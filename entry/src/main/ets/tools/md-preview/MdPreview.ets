/**
 * Markdown 预览的纯逻辑实现（行级渲染模型）。
 *
 * ## 输出是「渲染节点列表」而不是 HTML
 *
 * 页面把节点渲染成 ArkUI 组件（Text + RichText 风格），而不是拼 HTML 字符串——
 * 这样样式走主题 Token、字号走 scaled()，关怀模式天然生效。
 * 节点类型：heading(1-3) / paragraph / listitem / quote / code / hr。
 *
 * ## 行内样式的粒度
 *
 * 一个段落内的 **bold/italic/code** 三种行内样式用「片段列表」表达：
 * 页面对每段拆出多段 Text。粗体 `**x**`、斜体 `*x` 与 `_x_`、行内代码 \`x\`。
 *
 * ## 不支持的（limitation 会写明）
 *
 * 不做表格、不做嵌套列表、不做图片与链接跳转（链接只显示文本）、
 * 不做多级标题（只认 # / ## / ###）。
 *
 * @module tools/md-preview/MdPreview
 */

/** 块级节点类型 */
export enum MdBlockKind {
  HEADING = 'heading',
  PARAGRAPH = 'paragraph',
  LIST_ITEM = 'listitem',
  QUOTE = 'quote',
  CODE = 'code',
  HR = 'hr'
}

/** 行内片段：一段带样式的文本 */
export class MdInlineSpan {
  readonly text: string;
  readonly bold: boolean;
  readonly italic: boolean;
  readonly code: boolean;

  constructor(text: string, bold: boolean, italic: boolean, code: boolean) {
    this.text = text;
    this.bold = bold;
    this.italic = italic;
    this.code = code;
  }
}

/** 块级节点 */
export class MdBlock {
  readonly kind: MdBlockKind;
  /** heading 的级别（1-3），其它类型为 0 */
  readonly level: number;
  /** 行内片段（heading/paragraph/listitem/quote 用）；code 块用 rawText */
  readonly spans: Array<MdInlineSpan>;
  /** code 块与 hr 的原始文本 */
  readonly rawText: string;
  /** 有序列表的序号（从 1 起；无序列表为 0） */
  readonly order: number;

  constructor(kind: MdBlockKind, level: number, spans: Array<MdInlineSpan>, rawText: string, order: number) {
    this.kind = kind;
    this.level = level;
    this.spans = spans;
    this.rawText = rawText;
    this.order = order;
  }
}

/** 解析结果 */
export class MdParseResult {
  readonly ok: boolean;
  readonly blocks: Array<MdBlock>;

  constructor(ok: boolean, blocks: Array<MdBlock>) {
    this.ok = ok;
    this.blocks = blocks;
  }
}

const BACKTICK: string = String.fromCharCode(96);
const HASH: string = String.fromCharCode(35);
const STAR: string = String.fromCharCode(42);
const UNDERSCORE: string = String.fromCharCode(95);
const DASH: string = String.fromCharCode(45);
const GT: string = String.fromCharCode(62);

/** 是否是标题行（# 到 ###） */
function headingLevel(line: string): number {
  if (line.charAt(0) !== HASH) {
    return 0;
  }
  let level: number = 0;
  while (level < 3 && line.charAt(level) === HASH) {
    level++;
  }
  if (line.charAt(level) !== String.fromCharCode(32)) {
    return 0;
  }
  return level;
}

/** 是否是无序列表行（- 开头加空格） */
function isBulletItem(line: string): boolean {
  return line.charAt(0) === DASH && line.charAt(1) === String.fromCharCode(32);
}

/** 是否是有序列表行（数字. 空格） */
function orderedNumber(line: string): number {
  let i: number = 0;
  let digits: number = 0;
  while (i < line.length && line.charAt(i) >= '0' && line.charAt(i) <= '9') {
    i++;
    digits++;
  }
  if (digits === 0) {
    return 0;
  }
  if (line.charAt(i) === String.fromCharCode(46) && line.charAt(i + 1) === String.fromCharCode(32)) {
    return parseInt(line.substring(0, i), 10);
  }
  return 0;
}

/** 是否是引用行（> 开头） */
function isQuoteLine(line: string): boolean {
  return line.charAt(0) === GT && line.charAt(1) === String.fromCharCode(32);
}

/** 是否是水平线（--- 或 ***） */
function isHorizontalRule(line: string): boolean {
  if (line.length < 3) {
    return false;
  }
  let allDash: boolean = true;
  let allStar: boolean = true;
  for (let i = 0; i < line.length; i++) {
    if (line.charAt(i) !== DASH) {
      allDash = false;
    }
    if (line.charAt(i) !== STAR) {
      allStar = false;
    }
  }
  return allDash || allStar;
}

/**
 * 行内样式切分：code 优先（代码内的 * _ 不参与样式），其次 bold，再次 italic。
 */
export function splitInlineSpans(text: string): Array<MdInlineSpan> {
  const spans: Array<MdInlineSpan> = [];
  let plain: string = '';
  let i: number = 0;
  const pushPlain = (): void => {
    if (plain.length > 0) {
      spans.push(new MdInlineSpan(plain, false, false, false));
      plain = '';
    }
  };
  while (i < text.length) {
    const ch: string = text.charAt(i);
    if (ch === BACKTICK) {
      const end: number = text.indexOf(BACKTICK, i + 1);
      if (end > i) {
        pushPlain();
        spans.push(new MdInlineSpan(text.substring(i + 1, end), false, false, true));
        i = end + 1;
        continue;
      }
    }
    if (ch === STAR && i + 1 < text.length && text.charAt(i + 1) === STAR) {
      const end: number = text.indexOf(STAR + STAR, i + 2);
      if (end > i + 1) {
        pushPlain();
        spans.push(new MdInlineSpan(text.substring(i + 2, end), true, false, false));
        i = end + 2;
        continue;
      }
    }
    if ((ch === STAR || ch === UNDERSCORE) && i + 1 < text.length) {
      const closer: string = ch;
      const end: number = text.indexOf(closer, i + 1);
      if (end > i + 1) {
        pushPlain();
        spans.push(new MdInlineSpan(text.substring(i + 1, end), false, true, false));
        i = end + 1;
        continue;
      }
    }
    plain = plain + ch;
    i++;
  }
  pushPlain();
  if (spans.length === 0) {
    spans.push(new MdInlineSpan(text, false, false, false));
  }
  return spans;
}

/** 主入口：把 Markdown 文本切成块级节点列表 */
export function parseMarkdown(input: string): MdParseResult {
  const normalized: string = input.split(String.fromCharCode(13) + String.fromCharCode(10)).join(String.fromCharCode(10));
  const lines: Array<string> = normalized.split(String.fromCharCode(10));
  const blocks: Array<MdBlock> = [];
  let paragraph: Array<string> = [];
  const flushParagraph = (): void => {
    if (paragraph.length > 0) {
      blocks.push(new MdBlock(MdBlockKind.PARAGRAPH, 0,
        splitInlineSpans(paragraph.join(String.fromCharCode(32))), '', 0));
      paragraph = [];
    }
  };
  let inCode: boolean = false;
  let codeLines: Array<string> = [];
  for (let i = 0; i < lines.length; i++) {
    const raw: string = lines[i];
    const line: string = raw.trim();
    if (inCode) {
      if (line === BACKTICK + BACKTICK + BACKTICK) {
        blocks.push(new MdBlock(MdBlockKind.CODE, 0, [], codeLines.join(String.fromCharCode(10)), 0));
        codeLines = [];
        inCode = false;
      } else {
        codeLines.push(raw);
      }
      continue;
    }
    if (line === BACKTICK + BACKTICK + BACKTICK) {
      flushParagraph();
      inCode = true;
      continue;
    }
    if (line.length === 0) {
      flushParagraph();
      continue;
    }
    const h: number = headingLevel(line);
    if (h > 0) {
      flushParagraph();
      blocks.push(new MdBlock(MdBlockKind.HEADING, h,
        splitInlineSpans(line.substring(h + 1)), '', 0));
      continue;
    }
    if (isHorizontalRule(line)) {
      flushParagraph();
      blocks.push(new MdBlock(MdBlockKind.HR, 0, [], '', 0));
      continue;
    }
    if (isBulletItem(line)) {
      flushParagraph();
      blocks.push(new MdBlock(MdBlockKind.LIST_ITEM, 0,
        splitInlineSpans(line.substring(2)), '', 0));
      continue;
    }
    const ord: number = orderedNumber(line);
    if (ord > 0) {
      flushParagraph();
      const rest: number = line.indexOf(String.fromCharCode(32));
      blocks.push(new MdBlock(MdBlockKind.LIST_ITEM, 0,
        splitInlineSpans(line.substring(rest + 1)), '', ord));
      continue;
    }
    if (isQuoteLine(line)) {
      flushParagraph();
      blocks.push(new MdBlock(MdBlockKind.QUOTE, 0,
        splitInlineSpans(line.substring(2)), '', 0));
      continue;
    }
    paragraph.push(line);
  }
  if (inCode && codeLines.length > 0) {
    blocks.push(new MdBlock(MdBlockKind.CODE, 0, [], codeLines.join(String.fromCharCode(10)), 0));
  }
  flushParagraph();
  return new MdParseResult(true, blocks);
}
