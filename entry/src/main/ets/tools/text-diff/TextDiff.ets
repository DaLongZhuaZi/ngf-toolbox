/**
 * 文本 Diff —— 纯逻辑（零 import，可直接单测）。
 *
 * ## 算法与它的取舍
 *
 * 用经典的 **LCS（最长公共子序列）动态规划**做行级差异。它精确、可预测，
 * 而且输出可以对着「最少改动」解释清楚——这正是用户看 diff 时想要的。
 *
 * 代价是 O(n × m) 的时间与空间。文本 Diff 的输入来自用户粘贴，
 * 可能是整份日志（几万行），所以必须**主动设限**：
 * 超过 {@link DIFF_MAX_LINES} 行或规模上限时返回明确的失败，
 * 而不是让页面卡死。宁可说「太大了，先自己裁一下」，
 * 也不要让用户以为工具坏了。
 *
 * ## 为什么行尾统一按 LF 处理
 *
 * 用户粘贴的内容里 CRLF 与 LF 混杂是常态。若把 \\r 当成行内字符参与比较，
 * 会出现「每一行都不同」的荒谬结果——用户看到满屏红绿却找不到任何实际差异。
 * 因此本模块**先归一化行尾**再比较，并把「原本是 CRLF」这件事记录在
 * {@link DiffDocument} 里，供页面提示。
 *
 * @module tools/text-diff/TextDiff
 */

/** 单侧允许的最大行数（超过则拒绝，避免 O(n×m) 把页面拖死） */
export const DIFF_MAX_LINES: number = 2000;

/**
 * 允许的最大规模（行数乘积）。
 *
 * 2000 × 2000 = 400 万格，动态规划表按整数数组算约 16 MB，
 * 在手机上是可以接受的瞬时峰值；再大就该让用户自己裁了。
 */
export const DIFF_MAX_CELLS: number = 4000000;

/** 默认上下文行数（差异前后各显示几行未变的行） */
export const DIFF_CONTEXT_LINES: number = 2;

/** 一行在 diff 里的角色 */
export enum DiffLineKind {
  /** 两侧都有、内容相同 */
  KEEP = 'keep',
  /** 只在左侧（被删除） */
  REMOVE = 'remove',
  /** 只在右侧（新增） */
  ADD = 'add'
}

/** 归一化后的一个文档 */
export class DiffDocument {
  /** 归一化后的行数组（行尾已是 LF，不含换行符） */
  readonly lines: Array<string>;
  /** 原文是否以换行结尾。为 false 时页面要提示「末行没有换行符」 */
  readonly endsWithNewline: boolean;
  /** 原文里是否出现过 CRLF（出现过就提示用户行尾风格不一致） */
  readonly hasCarriageReturn: boolean;
  /** 归一化前的字符数，用于展示「你贴了多少字」 */
  readonly rawLength: number;

  constructor(
    lines: Array<string>,
    endsWithNewline: boolean,
    hasCarriageReturn: boolean,
    rawLength: number
  ) {
    this.lines = lines;
    this.endsWithNewline = endsWithNewline;
    this.hasCarriageReturn = hasCarriageReturn;
    this.rawLength = rawLength;
  }

  get lineCount(): number {
    return this.lines.length;
  }
}

/**
 * 按行切分并归一化行尾。
 *
 * 刻意不用 \`String.prototype.split(/\r?\n/)\`：那样拿不到「原文是否以换行结尾」，
 * 而这个信息会影响结论——"a\n" 与 "a" 差一个换行符，
 * 很多编辑器会因为丢掉它而在文件末尾报错。
 */
export function toDocument(text: string): DiffDocument {
  const endsWithNewline: boolean = text.length > 0
    && (text.charAt(text.length - 1) === '\n');
  const hasCarriageReturn: boolean = text.indexOf('\r') >= 0;

  const lines: Array<string> = [];
  let current: string = '';
  for (let i: number = 0; i < text.length; i++) {
    const ch: string = text.charAt(i);
    if (ch === '\r') {
      // CRLF 与单独的 CR 都当换行处理
      const next: string = i + 1 < text.length ? text.charAt(i + 1) : '';
      if (next === '\n') {
        i++;
      }
      lines.push(current);
      current = '';
      continue;
    }
    if (ch === '\n') {
      lines.push(current);
      current = '';
      continue;
    }
    current += ch;
  }
  // 收尾：不以换行结尾时，最后一段是真实的一行；
  // 以换行结尾时，最后一段是空串（换行后的空位置），不应算作一行。
  if (current.length > 0 || !endsWithNewline) {
    if (!(current.length === 0 && text.length === 0)) {
      lines.push(current);
    }
  }

  // 空文本 => 零行（而不是「一个空行」），否则「空 vs 一行空格」会被误判为无差异
  if (text.length === 0) {
    return new DiffDocument([], false, false, 0);
  }

  return new DiffDocument(lines, endsWithNewline, hasCarriageReturn, text.length);
}

/** diff 结果里的一行 */
export class DiffLine {
  readonly kind: DiffLineKind;
  readonly text: string;
  /** 左侧行号（1 起）；不存在时为 0 */
  readonly leftNumber: number;
  /** 右侧行号（1 起）；不存在时为 0 */
  readonly rightNumber: number;

  constructor(kind: DiffLineKind, text: string, leftNumber: number, rightNumber: number) {
    this.kind = kind;
    this.text = text;
    this.leftNumber = leftNumber;
    this.rightNumber = rightNumber;
  }

  /** 是否为「变更」行（新增或删除） */
  get isChanged(): boolean {
    return this.kind !== DiffLineKind.KEEP;
  }
}

/** diff 统计 */
export class DiffStats {
  readonly added: number;
  readonly removed: number;
  readonly kept: number;

  constructor(added: number, removed: number, kept: number) {
    this.added = added;
    this.removed = removed;
    this.kept = kept;
  }

  /** 两侧是否完全一致 */
  get identical(): boolean {
    return this.added === 0 && this.removed === 0;
  }
}

/** 一段连续的差异（含上下文） */
export class DiffHunk {
  /** 在该 hunk 里，左侧起始行号（1 起） */
  readonly leftStart: number;
  /** 右侧起始行号（1 起） */
  readonly rightStart: number;
  readonly lines: Array<DiffLine>;

  constructor(leftStart: number, rightStart: number, lines: Array<DiffLine>) {
    this.leftStart = leftStart;
    this.rightStart = rightStart;
    this.lines = lines;
  }
}

/** 完整 diff 结果 */
/**
 * 失败原因码。
 *
 * 纯逻辑不产出面向用户的句子——本模块不能 import ArkUI 的 \`$r()\`，
 * 因此没有能力按设备语言选文案。它只回答「为什么失败、文案需要哪些参数」，
 * 换人话的事交给 UI 层的 \`TextDiffMessages.ets\`。
 */
export enum DiffFailureCode {
  /** 没有失败（成功结果的占位，避免调用方到处判空） */
  NONE = 'none',
  /** 单侧行数超过上限 */
  TOO_MANY_LINES = 'too_many_lines',
  /** 两侧行数乘积超过上限 */
  MATRIX_TOO_LARGE = 'matrix_too_large'
}

/** 失败原因码 + 资源文案的占位符参数（顺序须与资源文案里 %s 一致） */
export class DiffFailure {
  readonly code: DiffFailureCode;
  readonly args: Array<string>;

  constructor(code: DiffFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }

  static none(): DiffFailure {
    return new DiffFailure(DiffFailureCode.NONE, []);
  }
}

export class DiffResult {
  readonly ok: boolean;
  /** 失败原因；成功时为 {@link DiffFailure.none}（**永不为 null**） */
  readonly failure: DiffFailure;
  readonly lines: Array<DiffLine>;
  readonly stats: DiffStats;

  constructor(ok: boolean, failure: DiffFailure, lines: Array<DiffLine>, stats: DiffStats) {
    this.ok = ok;
    this.failure = failure;
    this.lines = lines;
    this.stats = stats;
  }

  static failure(code: DiffFailureCode, args: Array<string>): DiffResult {
    return new DiffResult(false, new DiffFailure(code, args), [], new DiffStats(0, 0, 0));
  }
}

/**
 * 计算行级差异。
 *
 * 返回的 lines 是**完整**的逐行对照（含未变行），
 * 分页/折叠交给 {@link buildHunks}——两者分开是因为「算差异」与
 * 「决定给用户看多少」是两个独立决策。
 */
export function diffLines(left: DiffDocument, right: DiffDocument): DiffResult {
  const n: number = left.lines.length;
  const m: number = right.lines.length;

  if (n > DIFF_MAX_LINES || m > DIFF_MAX_LINES) {
    return DiffResult.failure(DiffFailureCode.TOO_MANY_LINES,
      [String(DIFF_MAX_LINES), String(n), String(m)]);
  }
  if (n * m > DIFF_MAX_CELLS) {
    return DiffResult.failure(DiffFailureCode.MATRIX_TOO_LARGE, [String(n), String(m)]);
  }

  // 长度不同的两行不可能相等，先算一个「相同」判定表，避免反复比较字符串。
  // 用一维数组按下标 i * m + j 存，省掉二维数组的开销。
  const lcs: Int32Array = new Int32Array((n + 1) * (m + 1));

  // 从后往前填表：lcs[i][j] = 左侧 i.. 与右侧 j.. 的最长公共子序列长度
  for (let i: number = n - 1; i >= 0; i--) {
    const leftLine: string = left.lines[i];
    for (let j: number = m - 1; j >= 0; j--) {
      const index: number = i * (m + 1) + j;
      if (leftLine === right.lines[j]) {
        lcs[index] = lcs[(i + 1) * (m + 1) + (j + 1)] + 1;
      } else {
        const down: number = lcs[(i + 1) * (m + 1) + j];
        const rightValue: number = lcs[i * (m + 1) + (j + 1)];
        lcs[index] = down >= rightValue ? down : rightValue;
      }
    }
  }

  // 回溯生成逐行结果
  const lines: Array<DiffLine> = [];
  let i: number = 0;
  let j: number = 0;
  let added: number = 0;
  let removed: number = 0;
  let kept: number = 0;

  while (i < n && j < m) {
    if (left.lines[i] === right.lines[j]) {
      lines.push(new DiffLine(DiffLineKind.KEEP, left.lines[i], i + 1, j + 1));
      kept += 1;
      i++;
      j++;
      continue;
    }
    const down: number = lcs[(i + 1) * (m + 1) + j];
    const rightValue: number = lcs[i * (m + 1) + (j + 1)];
    if (down >= rightValue) {
      // 删除左侧这一行更划算
      lines.push(new DiffLine(DiffLineKind.REMOVE, left.lines[i], i + 1, 0));
      removed += 1;
      i++;
    } else {
      lines.push(new DiffLine(DiffLineKind.ADD, right.lines[j], 0, j + 1));
      added += 1;
      j++;
    }
  }
  // 收尾：一侧先走完，剩下的全是新增或删除
  while (i < n) {
    lines.push(new DiffLine(DiffLineKind.REMOVE, left.lines[i], i + 1, 0));
    removed += 1;
    i++;
  }
  while (j < m) {
    lines.push(new DiffLine(DiffLineKind.ADD, right.lines[j], 0, j + 1));
    added += 1;
    j++;
  }

  return new DiffResult(true, DiffFailure.none(), lines, new DiffStats(added, removed, kept));
}

/**
 * 把逐行结果切成「差异块 + 上下文」，并把被略过的行折叠掉。
 *
 * 为什么需要它：一份 1000 行的文本只改了 2 行，用户要看的是那 2 行附近，
 * 而不是从头滚到尾。返回的 hunks 之间用「略过 N 行」表示，
 * 这个信息由页面转成一行提示。
 *
 * @param contextLines 每个 hunk 在差异前后各保留多少未变行
 */
export function buildHunks(result: DiffResult, contextLines: number): Array<DiffHunk> {
  const hunks: Array<DiffHunk> = [];
  if (!result.ok || result.lines.length === 0) {
    return hunks;
  }

  const lines: Array<DiffLine> = result.lines;
  const keepFlags: Array<boolean> = [];
  for (let i: number = 0; i < lines.length; i++) {
    keepFlags.push(!lines[i].isChanged);
  }

  // 先标记「要保留的行」：所有变更行，加上它们前后 contextLines 行范围内的未变行
  const selected: Array<boolean> = [];
  for (let i: number = 0; i < lines.length; i++) {
    selected.push(false);
  }
  for (let i: number = 0; i < lines.length; i++) {
    if (lines[i].isChanged) {
      const from: number = i - contextLines < 0 ? 0 : i - contextLines;
      const to: number = i + contextLines >= lines.length ? lines.length - 1 : i + contextLines;
      for (let k: number = from; k <= to; k++) {
        selected[k] = true;
      }
    }
  }

  // 相邻的保留段会被合并：中间只隔了几行未变的内容不值得再切一个块出来
  let index: number = 0;
  while (index < lines.length) {
    if (!selected[index]) {
      index++;
      continue;
    }
    const chunk: Array<DiffLine> = [];
    let start: number = index;
    while (index < lines.length && selected[index]) {
      chunk.push(lines[index]);
      index++;
    }
    let leftStart: number = 0;
    let rightStart: number = 0;
    for (let k: number = 0; k < chunk.length; k++) {
      if (leftStart === 0 && chunk[k].leftNumber > 0) {
        leftStart = chunk[k].leftNumber;
      }
      if (rightStart === 0 && chunk[k].rightNumber > 0) {
        rightStart = chunk[k].rightNumber;
      }
    }
    hunks.push(new DiffHunk(leftStart, rightStart, chunk));
  }

  return hunks;
}

/**
 * 按 hunk 生成统一的 diff 文本（供一键复制 / 贴进工单）。
 *
 * 格式贴近常见的 unified diff：\`-\` 表示只在左侧、\`+\` 表示只在右侧，
 * 被折叠掉的区域写成 \`@@ ... @@\`。刻意**不**生成可直接 \`patch\` 的格式——
 * 那需要精确的字节范围与文件头，超出本工具的范围（见 limitation）。
 */
export function toUnifiedText(result: DiffResult, hunks: Array<DiffHunk>, leftLabel: string,
  rightLabel: string, summaryLine: string): string {
  if (!result.ok) {
    // 失败时返回空串而不是错误文案：文案由 UI 层单独显示，
    // 混进「要复制走的差异文本」里只会让人误以为那段话也是差异内容。
    return '';
  }
  if (result.stats.identical) {
    return summaryLine;
  }

  let text: string = '--- ' + leftLabel + '\n';
  text += '+++ ' + rightLabel + '\n';
  // 统计行由调用方传入（已翻译）。
  // 为什么不在这里拼：'新增 N 行，删除 M 行' 的语序与量词因语言而异，
  // 纯逻辑层拿不到设备语言，拼出来必然是错的。格式（--- / +++ / @@）留在这里，
  // 因为那是**数据格式**而不是文案。
  text += summaryLine + '\n';

  for (let h: number = 0; h < hunks.length; h++) {
    const hunk: DiffHunk = hunks[h];
    text += '\n@@ -' + String(hunk.leftStart) + ' +' + String(hunk.rightStart)
      + ' @@\n';
    for (let k: number = 0; k < hunk.lines.length; k++) {
      const line: DiffLine = hunk.lines[k];
      if (line.kind === DiffLineKind.REMOVE) {
        text += '-' + line.text + '\n';
      } else if (line.kind === DiffLineKind.ADD) {
        text += '+' + line.text + '\n';
      } else {
        text += ' ' + line.text + '\n';
      }
    }
  }
  return text;
}

// ── 显示相关的判断（文案在 UI 层） ──────────────────────────────
//
// summarizeDiff / lineEndingNotice / trailingNewlineNotice 原本住在这里，
// 返回的是拼好的中文句子。做双语时把它们搬去了 TextDiffMessages.ets——
// 它们是**显示逻辑**，而纯逻辑层不能 import ArkUI 的 $r()，拼不出多语言句子。
//
// 留下的是「判断」而不是「措辞」：下面这三个函数只回答「有没有这种情况」，
// 措辞交给 UI 层。这样这些判断仍然可以在本机单测里覆盖
// （它们才是真正容易写错的部分：什么时候算行尾不一致、空文本要不要提示）。

/** 两侧是否存在行尾风格差异（一侧含 CR 而另一侧没有） */
export function hasLineEndingMismatch(left: DiffDocument, right: DiffDocument): boolean {
  if (left.hasCarriageReturn && right.hasCarriageReturn) {
    return false;
  }
  return left.hasCarriageReturn || right.hasCarriageReturn;
}

/** 两侧是否存在末尾换行差异（空文本不提示） */
export function hasTrailingNewlineMismatch(left: DiffDocument, right: DiffDocument): boolean {
  if (left.lineCount === 0 && right.lineCount === 0) {
    return false;
  }
  return left.endsWithNewline !== right.endsWithNewline;
}

/**
 * 摘要的**结构**：把「该说哪几句话」决定下来，措辞留给 UI 层。
 *
 * 页面顶部与「复制差异」需要同一份判断但措辞略有不同（一个偏叙述、一个偏紧凑），
 * 所以这里给出的是「命中哪些情况 + 相关数字」，由 UI 层各自组装。
 */
export class DiffSummaryFacts {
  readonly ok: boolean;
  readonly identical: boolean;
  readonly added: number;
  readonly removed: number;
  readonly kept: number;
  readonly leftLines: number;
  readonly rightLines: number;
  /** 行数相同但内容不同：最常见的「改了内容没改行数」 */
  readonly sameLineCountRewrite: boolean;
  /** 两侧总行数不同 */
  readonly lineCountDiffers: boolean;

  constructor(ok: boolean, identical: boolean, added: number, removed: number, kept: number,
    leftLines: number, rightLines: number, sameLineCountRewrite: boolean, lineCountDiffers: boolean) {
    this.ok = ok;
    this.identical = identical;
    this.added = added;
    this.removed = removed;
    this.kept = kept;
    this.leftLines = leftLines;
    this.rightLines = rightLines;
    this.sameLineCountRewrite = sameLineCountRewrite;
    this.lineCountDiffers = lineCountDiffers;
  }
}

/** 汇总摘要所需的事实（不含任何措辞） */
export function diffSummaryFacts(result: DiffResult, left: DiffDocument,
  right: DiffDocument): DiffSummaryFacts {
  const stats: DiffStats = result.stats;
  const lineCountDiffers: boolean = left.lineCount !== right.lineCount;
  const sameLineCountRewrite: boolean = !lineCountDiffers && stats.added === stats.removed
    && !stats.identical;
  return new DiffSummaryFacts(result.ok, stats.identical, stats.added, stats.removed, stats.kept,
    left.lineCount, right.lineCount, sameLineCountRewrite, lineCountDiffers);
}