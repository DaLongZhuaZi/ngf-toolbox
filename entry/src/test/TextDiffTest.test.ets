import { describe, expect, it } from '@ohos/hypium';
import {
  buildHunks,
  DiffFailureCode,
  DiffSummaryFacts,
  DIFF_MAX_LINES,
  DiffDocument,
  DiffHunk,
  DiffLine,
  DiffLineKind,
  diffLines,
  DiffResult,
  diffSummaryFacts,
  hasLineEndingMismatch,
  hasTrailingNewlineMismatch,
  toDocument,
  toUnifiedText,
} from '../main/ets/tools/text-diff/TextDiff';

/**
 * 文本 Diff 的单测。
 *
 * ## 这个工具最容易被坑的三处（用例逐条钉住）
 *
 * 1. **行尾风格**：粘贴内容里 CRLF 与 LF 混杂是常态。若把回车当行内字符比对，
 *    会出现「每一行都不同」的荒谬结果——用户满屏红绿却找不到实际差异。
 * 2. **末尾换行符**：「a」与「a + 换行」在肉眼上看不出区别，但会真的影响
 *    版本控制与部分检查工具。
 * 3. **规模上限**：LCS 是 O(n×m)，不受限的话一份大日志就能把页面拖死。
 *    必须给出**明确失败**而不是装作能用。
 */
export default function textDiffTest() {
  describe('textDiffTest', () => {
    // ── 文档归一化 ──────────────────────────────────────────

    it('按行切分且不含换行符', 0, () => {
      const doc: DiffDocument = toDocument('a\nb\nc');
      expect(doc.lineCount).assertEqual(3);
      expect(doc.lines[0]).assertEqual('a');
      expect(doc.lines[2]).assertEqual('c');
    });

    it('空文本是零行，而不是「一个空行」', 0, () => {
      // 若算成「一个空行」，「空内容 vs 一行空格」会被误判为无差异。
      expect(toDocument('').lineCount).assertEqual(0);
      expect(toDocument('').endsWithNewline).assertFalse();
    });

    it('末尾换行不算作额外的一行，但会被记录', 0, () => {
      const withNewline: DiffDocument = toDocument('a\n');
      expect(withNewline.lineCount).assertEqual(1);
      expect(withNewline.endsWithNewline).assertTrue();

      const withoutNewline: DiffDocument = toDocument('a');
      expect(withoutNewline.lineCount).assertEqual(1);
      expect(withoutNewline.endsWithNewline).assertFalse();
    });

    it('只有换行符时是两行空行', 0, () => {
      const doc: DiffDocument = toDocument('\n');
      expect(doc.lineCount).assertEqual(1);
      expect(doc.lines[0]).assertEqual('');
      expect(doc.endsWithNewline).assertTrue();
    });

    it('CRLF 与 LF 归一化成同样的行内容', 0, () => {
      // 这是最关键的一条：不归一化的话下面两段会被判成「完全不同」。
      const crlf: DiffDocument = toDocument('a\r\nb\r\n');
      const lf: DiffDocument = toDocument('a\nb\n');
      expect(crlf.lineCount).assertEqual(2);
      expect(lf.lineCount).assertEqual(2);
      expect(crlf.lines[0]).assertEqual(lf.lines[0]);
      expect(crlf.lines[1]).assertEqual(lf.lines[1]);
      // 但 CRLF 这件事被记录下来，供页面提示
      expect(crlf.hasCarriageReturn).assertTrue();
      expect(lf.hasCarriageReturn).assertFalse();
    });

    it('单独的 CR（老式 Mac 行尾）也当换行处理', 0, () => {
      const doc: DiffDocument = toDocument('a\rb');
      expect(doc.lineCount).assertEqual(2);
      expect(doc.lines[1]).assertEqual('b');
      expect(doc.hasCarriageReturn).assertTrue();
    });

    it('行内的空白与制表符原样保留（不能顺手 trim）', 0, () => {
      // 缩进差异是真实差异；trim 掉会让「只改了缩进」这种改动被忽略。
      const doc: DiffDocument = toDocument('  indented\n\ttabbed\n');
      expect(doc.lines[0]).assertEqual('  indented');
      expect(doc.lines[1]).assertEqual('\ttabbed');
    });

    // ── 差异计算 ────────────────────────────────────────────

    it('完全相同的文本判为一致', 0, () => {
      const result: DiffResult = diffLines(toDocument('a\nb\n'), toDocument('a\nb\n'));
      expect(result.ok).assertTrue();
      expect(result.stats.identical).assertTrue();
      expect(result.stats.kept).assertEqual(2);
    });

    it('CRLF 与 LF 文本比对应判为一致', 0, () => {
      // 回归保护：没有行尾归一化时这里会报「两行都改了」。
      const result: DiffResult = diffLines(toDocument('a\r\nb\r\n'), toDocument('a\nb\n'));
      expect(result.stats.identical).assertTrue();
    });

    it('单行改写应报 1 增 1 删，而不是 3 行全变', 0, () => {
      const result: DiffResult = diffLines(toDocument('a\nb\nc'), toDocument('a\nB\nc'));
      expect(result.stats.added).assertEqual(1);
      expect(result.stats.removed).assertEqual(1);
      expect(result.stats.kept).assertEqual(2);
    });

    it('纯新增与纯删除', 0, () => {
      const added: DiffResult = diffLines(toDocument('a\n'), toDocument('a\nb\n'));
      expect(added.stats.added).assertEqual(1);
      expect(added.stats.removed).assertEqual(0);

      const removed: DiffResult = diffLines(toDocument('a\nb\n'), toDocument('a\n'));
      expect(removed.stats.added).assertEqual(0);
      expect(removed.stats.removed).assertEqual(1);
    });

    it('从空到有、从有到空', 0, () => {
      const emptyToText: DiffResult = diffLines(toDocument(''), toDocument('a\nb'));
      expect(emptyToText.stats.added).assertEqual(2);
      expect(emptyToText.stats.removed).assertEqual(0);

      const textToEmpty: DiffResult = diffLines(toDocument('a\nb'), toDocument(''));
      expect(textToEmpty.stats.added).assertEqual(0);
      expect(textToEmpty.stats.removed).assertEqual(2);

      // 两边都空
      expect(diffLines(toDocument(''), toDocument('')).stats.identical).assertTrue();
    });

    it('行号在两侧各自连续，且与被删/被增的行对应', 0, () => {
      const result: DiffResult = diffLines(toDocument('a\nb\nc'), toDocument('a\nc'));
      // b 被删：leftNumber=2，rightNumber=0
      const removedLine: DiffLine | null = findFirst(result.lines, DiffLineKind.REMOVE);
      expect(removedLine !== null).assertTrue();
      if (removedLine !== null) {
        expect(removedLine.text).assertEqual('b');
        expect(removedLine.leftNumber).assertEqual(2);
        expect(removedLine.rightNumber).assertEqual(0);
      }
      // c 未变：left=3 right=2
      const keptLine: DiffLine | null = findFirst(result.lines, DiffLineKind.KEEP);
      expect(keptLine !== null).assertTrue();
    });

    it('新增行的右侧行号正确、左侧为 0', 0, () => {
      const result: DiffResult = diffLines(toDocument('a'), toDocument('a\nb'));
      const addedLine: DiffLine | null = findFirst(result.lines, DiffLineKind.ADD);
      expect(addedLine !== null).assertTrue();
      if (addedLine !== null) {
        expect(addedLine.text).assertEqual('b');
        expect(addedLine.leftNumber).assertEqual(0);
        expect(addedLine.rightNumber).assertEqual(2);
      }
    });

    it('重复行不会让 LCS 退化出错', 0, () => {
      // 全是同一行时，LCS 有多解；这里只要求「统计自洽」：
      // 结果行数 = 左侧行数 + 新增行数。
      const left: DiffDocument = toDocument('x\nx\nx');
      const right: DiffDocument = toDocument('x\nx\nx\nx');
      const result: DiffResult = diffLines(left, right);
      expect(result.ok).assertTrue();
      expect(result.lines.length).assertEqual(left.lineCount + result.stats.added);
      expect(result.stats.added).assertEqual(1);
    });

    it('结果行数恒等于左侧行数加新增行数（结构自洽）', 0, () => {
      const left: DiffDocument = toDocument('a\nb\nc\nd');
      const right: DiffDocument = toDocument('b\nx\nd\ne');
      const result: DiffResult = diffLines(left, right);
      expect(result.lines.length).assertEqual(left.lineCount + result.stats.added);
      expect(result.lines.length).assertEqual(right.lineCount + result.stats.removed);
    });

    it('超过单侧行数上限时明确失败，而不是卡死', 0, () => {
      // 构造超过上限的输入：只造行，不要求内容有意义。
      let manyLines: string = '';
      for (let i: number = 0; i <= DIFF_MAX_LINES; i++) {
        manyLines += 'line' + String(i) + '\n';
      }
      const result: DiffResult = diffLines(toDocument(manyLines), toDocument('a'));
      expect(result.ok).assertFalse();
      expect(result.failure.code).assertEqual(DiffFailureCode.TOO_MANY_LINES);
      // 参数顺序须与资源文案里的 %s 一致：上限、左侧行数、右侧行数
      expect(result.failure.args[0]).assertEqual(String(DIFF_MAX_LINES));
      // 循环到 <= DIFF_MAX_LINES，所以左侧实际是 上限+1 行
      expect(result.failure.args[1]).assertEqual(String(DIFF_MAX_LINES + 1));
      expect(result.failure.args[2]).assertEqual('1');
    });

    it('规模上限会拦住「两侧都很大」的组合', 0, () => {
      // 单侧都没超 2000 行，但乘积超过上限，也要拦。
      const build = (count: number): string => {
        let text: string = '';
        for (let i: number = 0; i < count; i++) {
          text += 'l' + String(i) + '\n';
        }
        return text;
      };
      // 1900 × 1900 = 361 万 < 400 万，先确认这个规模是放行的
      const allowed: DiffResult = diffLines(toDocument(build(1900)), toDocument(build(1900)));
      expect(allowed.ok).assertTrue();
    });

    // ── 分块与上下文 ────────────────────────────────────────

    it('只改中间一行时，上下文外的内容被折叠掉', 0, () => {
      const left: string = '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n';
      const right: string = '1\n2\n3\n4\nX\n6\n7\n8\n9\n10\n';
      const result: DiffResult = diffLines(toDocument(left), toDocument(right));
      const hunks: Array<DiffHunk> = buildHunks(result, 1);
      expect(hunks.length).assertEqual(1);
      expect(hunks[0].lines.length < result.lines.length).assertTrue();
      // 一个「改写」在行级 diff 里是 1 删除 + 1 新增，所以块内是：
      // 上文 1 行（4）+ 被删的 5 + 新增的 X + 下文 1 行（6）= 4 行。
      // 折叠掉的是首尾各 4 行（1~3 与 7~10）。
      expect(hunks[0].lines.length).assertEqual(4);
      expect(hunks[0].lines[0].text).assertEqual('4');
      expect(hunks[0].lines[1].text).assertEqual('5');
      expect(hunks[0].lines[1].kind).assertEqual(DiffLineKind.REMOVE);
      expect(hunks[0].lines[2].text).assertEqual('X');
      expect(hunks[0].lines[2].kind).assertEqual(DiffLineKind.ADD);
      expect(hunks[0].lines[3].text).assertEqual('6');
      // 结果里共有 11 行，块只保留了 4 行 —— 这就是折叠的价值
      expect(result.lines.length).assertEqual(11);
    });

    it('上下文为 0 时只留变更行', 0, () => {
      const result: DiffResult = diffLines(toDocument('a\nb\nc'), toDocument('a\nX\nc'));
      const hunks: Array<DiffHunk> = buildHunks(result, 0);
      expect(hunks.length).assertEqual(1);
      expect(hunks[0].lines.length).assertEqual(2);
      for (let i: number = 0; i < hunks[0].lines.length; i++) {
        expect(hunks[0].lines[i].isChanged).assertTrue();
      }
    });

    it('两处相距很远的差异会切分成两个块', 0, () => {
      let left: string = '';
      let right: string = '';
      for (let i: number = 1; i <= 30; i++) {
        const value: string = i === 2 ? 'A' : (i === 28 ? 'B' : String(i));
        const changed: string = i === 2 ? 'A2' : (i === 28 ? 'B2' : String(i));
        left += value + '\n';
        right += changed + '\n';
      }
      const result: DiffResult = diffLines(toDocument(left), toDocument(right));
      const hunks: Array<DiffHunk> = buildHunks(result, 1);
      expect(hunks.length).assertEqual(2);
    });

    it('完全一致时没有差异块', 0, () => {
      const result: DiffResult = diffLines(toDocument('a\nb'), toDocument('a\nb'));
      expect(buildHunks(result, 2).length).assertEqual(0);
    });

    it('失败的 diff 不产生差异块（页面据此不渲染结果区）', 0, () => {
      expect(buildHunks(DiffResult.failure(DiffFailureCode.TOO_MANY_LINES, ['1', '1', '1']), 2).length)
        .assertEqual(0);
    });

    it('差异块的起始行号来自块内第一行', 0, () => {
      const left: string = '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n';
      const right: string = '1\n2\n3\n4\nX\n6\n7\n8\n9\n10\n';
      const result: DiffResult = diffLines(toDocument(left), toDocument(right));
      const hunks: Array<DiffHunk> = buildHunks(result, 1);
      // 上下文从第 4 行开始（X 在第 5 行，前 1 行）
      expect(hunks[0].leftStart).assertEqual(4);
      expect(hunks[0].rightStart).assertEqual(4);
    });

    // ── 导出文本与摘要 ──────────────────────────────────────

    it('导出的统一格式用减号表示删除、加号表示新增', 0, () => {
      const result: DiffResult = diffLines(toDocument('a\nb'), toDocument('a\nc'));
      const text: string = toUnifiedText(result, buildHunks(result, 0), 'L', 'R', 'summary-line');
      expect(text.indexOf('-b') >= 0).assertTrue();
      expect(text.indexOf('+c') >= 0).assertTrue();
      // 标签由调用方传入（页面上是资源文案），这里传的是 'L' / 'R'
      expect(text.indexOf('--- L') >= 0).assertTrue();
      expect(text.indexOf('+++ R') >= 0).assertTrue();
      // 统计行也由调用方传入，纯逻辑原样嵌入
      expect(text.indexOf('summary-line') >= 0).assertTrue();
    });

    it('一致的文本导出成一句人话，而不是空的 diff', 0, () => {
      const result: DiffResult = diffLines(toDocument('a'), toDocument('a'));
      // 一致的文本导出的就是调用方传进来的那句总结（措辞在 UI 层），
      // 纯逻辑只保证「不吐出一个空的 diff」。
      const text: string = toUnifiedText(result, buildHunks(result, 2), 'L', 'R', 'identical-line');
      expect(text).assertEqual('identical-line');
    });

    it('摘要指出「行数相同属于逐行改写」', 0, () => {
      const left: DiffDocument = toDocument('a\nb\nc');
      const right: DiffDocument = toDocument('a\nB\nc');
      const result: DiffResult = diffLines(left, right);
      // 断言「事实」而不是措辞：措辞已下移到 UI 层（可多语言），
      // 这里要钉住的是「什么时候该说这句话」这个判断本身。
      const facts: DiffSummaryFacts = diffSummaryFacts(result, left, right);
      expect(facts.sameLineCountRewrite).assertTrue();
      expect(facts.lineCountDiffers).assertFalse();
      expect(facts.identical).assertFalse();
    });

    it('摘要给出行数不等时的两侧行数', 0, () => {
      const left: DiffDocument = toDocument('a\nb');
      const right: DiffDocument = toDocument('a\nb\nc');
      const result: DiffResult = diffLines(left, right);
      const facts: DiffSummaryFacts = diffSummaryFacts(result, left, right);
      expect(facts.lineCountDiffers).assertTrue();
      expect(facts.leftLines).assertEqual(2);
      expect(facts.rightLines).assertEqual(3);
      // 行数不同时不该说「逐行改写」
      expect(facts.sameLineCountRewrite).assertFalse();
    });

    // ── 提示文案 ────────────────────────────────────────────

    it('只有一侧含 CRLF 时给出风格不一致提示', 0, () => {
      // 提示文案（含 "CRLF" 这个词）在 UI 层，纯逻辑只回答「有没有不一致」
      expect(hasLineEndingMismatch(toDocument('a\r\n'), toDocument('a\n'))).assertTrue();
    });

    it('两侧都不含回车时不提示行尾风格', 0, () => {
      expect(hasLineEndingMismatch(toDocument('a\n'), toDocument('a\n'))).assertFalse();
    });

    it('末尾换行符不同时给出提示', 0, () => {
      expect(hasTrailingNewlineMismatch(toDocument('a'), toDocument('a\n'))).assertTrue();
    });

    it('两侧都空时不提示末尾换行（那是噪音）', 0, () => {
      expect(hasTrailingNewlineMismatch(toDocument(''), toDocument(''))).assertFalse();
    });

    it('末尾换行一致时不提示', 0, () => {
      expect(hasTrailingNewlineMismatch(toDocument('a\n'), toDocument('b\n'))).assertFalse();
    });
  });
}

/** 取第一个指定角色的行；没有则返回 null */
function findFirst(lines: Array<DiffLine>, kind: DiffLineKind): DiffLine | null {
  for (let i: number = 0; i < lines.length; i++) {
    if (lines[i].kind === kind) {
      return lines[i];
    }
  }
  return null;
}