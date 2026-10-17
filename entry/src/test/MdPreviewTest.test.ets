import { describe, expect, it } from '@ohos/hypium';
import {
  MdBlockKind,
  parseMarkdown,
  splitInlineSpans
} from '../main/ets/tools/md-preview/MdPreview';

/**
 * Markdown 解析的单测。
 *
 * 重点：行内样式边界（** 未闭合就当纯文本）、代码块内的标记不参与样式、
 * 段落聚合（连续非空行归一段）。
 */
const BT: string = String.fromCharCode(96);
const HASH: string = String.fromCharCode(35);
const STAR: string = String.fromCharCode(42);
const LF: string = String.fromCharCode(10);
const DASH: string = String.fromCharCode(45);
const GT: string = String.fromCharCode(62);

export default function mdPreviewTest() {
  describe('mdPreviewTest', () => {
    it('三级标题：# / ## / ### 带级别', 0, () => {
      const r = parseMarkdown(HASH + ' One' + LF + HASH + HASH + ' Two' + LF + HASH + HASH + HASH + ' Three');
      expect(r.blocks.length).assertEqual(3);
      expect(r.blocks[0].kind).assertEqual(MdBlockKind.HEADING);
      expect(r.blocks[0].level).assertEqual(1);
      expect(r.blocks[1].level).assertEqual(2);
      expect(r.blocks[2].level).assertEqual(3);
      expect(r.blocks[0].spans[0].text).assertEqual('One');
    });

    it('#### 四个井号不是标题（按段落处理）', 0, () => {
      const r = parseMarkdown(HASH + HASH + HASH + HASH + ' Four');
      expect(r.blocks.length).assertEqual(1);
      expect(r.blocks[0].kind).assertEqual(MdBlockKind.PARAGRAPH);
    });

    it('行内样式：粗体 / 斜体 / 行内代码', 0, () => {
      const spans = splitInlineSpans('a ' + STAR + STAR + 'b' + STAR + STAR + ' c');
      expect(spans.length).assertEqual(3);
      expect(spans[1].bold).assertEqual(true);
      const it2 = splitInlineSpans('x' + STAR + 'y' + STAR + 'z');
      expect(it2[1].italic).assertEqual(true);
      const c = splitInlineSpans('p ' + BT + 'q' + BT + ' r');
      expect(c[1].code).assertEqual(true);
    });

    it('未闭合的 ** 当纯文本（不吞后半段）', 0, () => {
      const spans = splitInlineSpans('a ' + STAR + STAR + 'b');
      expect(spans.length).assertEqual(1);
      expect(spans[0].bold).assertEqual(false);
      expect(spans[0].text).assertEqual('a ' + STAR + STAR + 'b');
    });

    it('代码块内的星号不参与样式', 0, () => {
      const r = parseMarkdown(BT + BT + BT + LF + STAR + STAR + 'x' + STAR + STAR + LF + BT + BT + BT);
      expect(r.blocks.length).assertEqual(1);
      expect(r.blocks[0].kind).assertEqual(MdBlockKind.CODE);
      expect(r.blocks[0].rawText).assertEqual(STAR + STAR + 'x' + STAR + STAR);
    });

    it('列表：无序与有序，序号提取', 0, () => {
      const r = parseMarkdown(DASH + ' item' + LF + '2. second');
      expect(r.blocks.length).assertEqual(2);
      expect(r.blocks[0].kind).assertEqual(MdBlockKind.LIST_ITEM);
      expect(r.blocks[0].order).assertEqual(0);
      expect(r.blocks[1].order).assertEqual(2);
    });

    it('引用与水平线', 0, () => {
      const r = parseMarkdown(GT + ' quote' + LF + DASH + DASH + DASH);
      expect(r.blocks[0].kind).assertEqual(MdBlockKind.QUOTE);
      expect(r.blocks[1].kind).assertEqual(MdBlockKind.HR);
    });

    it('段落聚合：连续非空行归一段（空格连接）', 0, () => {
      const r = parseMarkdown('line one' + LF + 'line two' + LF + LF + 'next');
      expect(r.blocks.length).assertEqual(2);
      expect(r.blocks[0].spans[0].text).assertEqual('line one line two');
    });

    it('空输入返回空块列表（合法状态）', 0, () => {
      const r = parseMarkdown('');
      expect(r.ok).assertEqual(true);
      expect(r.blocks.length).assertEqual(0);
    });
  });
}
