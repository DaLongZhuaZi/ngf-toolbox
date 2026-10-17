import { describe, expect, it } from '@ohos/hypium';
import {
  computeStats,
  detectLineEndings,
  LineSortMode,
  processLines,
  splitLines,
  TextToolkitFailureCode
} from '../main/ets/tools/text-toolkit/TextToolkit';

/**
 * 文本行工具的单测。
 *
 * 三个高危点：CRLF 与 LF 混排、去重后统计口径（基于剔除后的行）、
 * 排序的稳定性（同长度行不打乱原相对顺序）。
 */
export default function textToolkitTest() {
  describe('textToolkitTest', () => {
    it('splitLines：CRLF/LF 混排与末尾换行', 0, () => {
      expect(splitLines('a' + String.fromCharCode(13) + String.fromCharCode(10) + 'b' + String.fromCharCode(10) + 'c').join('|')).assertEqual('a|b|c');
      expect(splitLines('a' + String.fromCharCode(10) + String.fromCharCode(10)).length).assertEqual(1);
      expect(splitLines('a' + String.fromCharCode(10) + String.fromCharCode(10) + 'b').length).assertEqual(3);
    });

    it('去重保留首次出现并给出剔除数', 0, () => {
      const r = processLines('b\na\nb\na\nc', LineSortMode.ORIGINAL, true, false, true);
      expect(r.ok).assertEqual(true);
      expect(r.lines.join('|')).assertEqual('b|a|c');
      expect(r.removedDuplicates).assertEqual(2);
    });

    it('字典序排序不按码位（A 与 a 相邻，Z 不排在 a 前）', 0, () => {
      const r = processLines('b\nA\na\nC', LineSortMode.LEXICAL, false, false, false);
      expect(r.lines.join('|')).assertEqual('a|A|b|C');
    });

    it('按长度升序', 0, () => {
      const r = processLines('ccc\na\nbb', LineSortMode.LENGTH_ASC, false, false, false);
      expect(r.lines.join('|')).assertEqual('a|bb|ccc');
    });

    it('trim 后再去重：带首尾空白的重复行也算重复', 0, () => {
      const r = processLines('x\n x \nx', LineSortMode.ORIGINAL, true, true, true);
      expect(r.lines.join('|')).assertEqual('x');
      expect(r.removedDuplicates).assertEqual(2);
    });

    it('统计：字符/非空白字符/词数基于剔除后的行', 0, () => {
      const r = processLines('hello world' + String.fromCharCode(10) + String.fromCharCode(10) + 'ab', LineSortMode.ORIGINAL, false, false, true);
      expect(r.stats.totalLines).assertEqual(2);
      expect(r.stats.nonEmptyLines).assertEqual(2);
      expect(r.stats.chars).assertEqual(13);
      expect(r.stats.words).assertEqual(3);
    });

    it('行尾检测：CRLF 与 LF 计数', 0, () => {
      const e = detectLineEndings('a' + String.fromCharCode(13) + String.fromCharCode(10) + 'b' + String.fromCharCode(10) + 'c' + String.fromCharCode(13) + String.fromCharCode(10));
      expect(e.length).assertEqual(3);
      expect(e[0]).assertEqual(String.fromCharCode(13) + String.fromCharCode(10));
      expect(e[1]).assertEqual(String.fromCharCode(10));
      const s = computeStats(['a', 'b'], e);
      expect(s.crlfLines).assertEqual(2);
      expect(s.lfLines).assertEqual(1);
    });

    it('空输入与纯空白行各报对错误码', 0, () => {
      expect(processLines('', LineSortMode.ORIGINAL, true, false, true).failure.code)
        .assertEqual(TextToolkitFailureCode.EMPTY_INPUT);
      expect(processLines('   ' + String.fromCharCode(10) + ' ' + String.fromCharCode(10), LineSortMode.ORIGINAL, false, true, true).failure.code)
        .assertEqual(TextToolkitFailureCode.EMPTY_INPUT);
    });

    it('同长度行排序保持稳定（两次运行顺序一致）', 0, () => {
      const a = processLines('bb\naa\ncc', LineSortMode.LENGTH_ASC, false, false, false);
      const b = processLines('bb\naa\ncc', LineSortMode.LENGTH_ASC, false, false, false);
      expect(a.lines.join('|')).assertEqual(b.lines.join('|'));
    });
  });
}
