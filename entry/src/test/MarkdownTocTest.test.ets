import { describe, expect, it } from '@ohos/hypium';
import {
  buildToc,
  slugify,
  TocFailureCode
} from '../main/ets/tools/markdown-toc/MarkdownTocLogic';

const LF = String.fromCharCode(10);
const H = String.fromCharCode(35);
const BT = String.fromCharCode(96);

/**
 * Markdown 目录的单测：标题扫描/代码块跳过/slug 规则/错误路径。
 */
export default function markdownTocTest() {
  describe('markdownTocTest', () => {
    it('三级标题缩进正确', 0, () => {
      const r = buildToc(H + ' A' + LF + H + H + ' B' + LF + H + H + H + ' C');
      expect(r.ok).assertEqual(true);
      expect(r.items.length).assertEqual(3);
      expect(r.items[0].level).assertEqual(1);
      expect(r.items[2].level).assertEqual(3);
      expect(r.markdown.indexOf('  - [B](#b)') >= 0).assertEqual(true);
    });

    it('slug：空格转横线、去标点、保留中文', 0, () => {
      expect(slugify('Hello World')).assertEqual('hello-world');
      expect(slugify('安装 指南!')).assertEqual('安装-指南');
      expect(slugify('a--b')).assertEqual('a--b');
    });

    it('代码块内的井号行跳过', 0, () => {
      const md = H + ' Real' + LF + BT + BT + BT + LF + H + ' Fake' + LF + BT + BT + BT;
      const r = buildToc(md);
      expect(r.items.length).assertEqual(1);
      expect(r.items[0].text).assertEqual('Real');
    });

    it('四级及更深标题忽略', 0, () => {
      const r = buildToc(H + H + H + H + ' Deep');
      expect(r.failure.code).assertEqual(TocFailureCode.NO_HEADINGS);
    });

    it('无标题报错；空输入报错', 0, () => {
      expect(buildToc('plain text only').failure.code).assertEqual(TocFailureCode.NO_HEADINGS);
      expect(buildToc('').failure.code).assertEqual(TocFailureCode.EMPTY_INPUT);
    });
  });
}