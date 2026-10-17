import { describe, expect, it } from '@ohos/hypium';
import {
  checkLinks,
  MdLinkKind
} from '../main/ets/tools/md-link-check/MdLinkCheckLogic';

/**
 * Markdown 链接检查的单测：分类、图片、重复、空 target。
 */
export default function mdLinkCheckTest() {
  describe('mdLinkCheckTest', () => {
    it('四类链接分类正确', 0, () => {
      const md = '[a](#sec)' + LF + '[b](./local.md)' + LF + '[c](https://x.test)' + LF + '[d](mailto:a@b.c)';
      const r = checkLinks(md);
      expect(r.links.length).assertEqual(4);
      expect(r.links[0].kind).assertEqual(MdLinkKind.ANCHOR);
      expect(r.links[1].kind).assertEqual(MdLinkKind.RELATIVE);
      expect(r.links[2].kind).assertEqual(MdLinkKind.ABSOLUTE);
      expect(r.links[3].kind).assertEqual(MdLinkKind.OTHER_PROTOCOL);
    });

    it('图片标记 isImage', 0, () => {
      const r = checkLinks('![alt](img.png)');
      expect(r.links.length).assertEqual(1);
      expect(r.links[0].isImage).assertEqual(true);
    });

    it('重复 target 检出', 0, () => {
      const r = checkLinks('[a](same.md)' + LF + '[b](same.md)');
      expect(r.duplicates.length).assertEqual(1);
      expect(r.duplicates[0]).assertEqual('same.md');
    });

    it('空 target 计数', 0, () => {
      const r = checkLinks('[a]()' + LF + '[b](x.md)');
      expect(r.emptyTargets).assertEqual(1);
    });

    it('行号正确', 0, () => {
      const r = checkLinks('intro' + LF + '[link](x.md)');
      expect(r.links[0].line).assertEqual(2);
    });

    it('空输入报错', 0, () => {
      expect(checkLinks('').failure.code).assertEqual('empty_input');
    });
  });
}
const LF = String.fromCharCode(10);
