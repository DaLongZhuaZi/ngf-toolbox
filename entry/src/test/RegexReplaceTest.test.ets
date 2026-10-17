import { describe, expect, it } from '@ohos/hypium';
import {
  replacePreview,
  RegexReplaceFailureCode
} from '../main/ets/tools/regex-replace/RegexReplaceLogic';

/**
 * 正则替换预览的单测：替换语义 + 匹配清单 + 标志处理。
 */
export default function regexReplaceTest() {
  describe('regexReplaceTest', () => {
    it('简单替换：全量 g', 0, () => {
      const r = replacePreview('a-b-c', '-', 'g', '');
      expect(r.ok).assertEqual(true);
      expect(r.replaced).assertEqual('abc');
      expect(r.matches.length).assertEqual(2);
      expect(r.global).assertEqual(true);
    });

    it('g 标志：全部替换；无 g：只替换第一处', 0, () => {
      const all = replacePreview('aaa', 'a', 'g', 'b');
      expect(all.replaced).assertEqual('bbb');
      expect(all.matches.length).assertEqual(3);
      const first = replacePreview('aaa', 'a', '', 'b');
      expect(first.replaced).assertEqual('baa');
      expect(first.matches.length).assertEqual(1);
    });

    it('捕获组 $1', 0, () => {
      const r = replacePreview('john smith', '(\\w+) (\\w+)', '', '$2 $1');
      expect(r.replaced).assertEqual('smith john');
    });

    it('i 标志：大小写不敏感', 0, () => {
      const r = replacePreview('Hello HELLO', 'hello', 'gi', 'X');
      expect(r.replaced).assertEqual('X X');
      expect(r.matches.length).assertEqual(2);
    });

    it('匹配清单：原文与位置', 0, () => {
      const r = replacePreview('abc abc', 'b', 'g', '-');
      expect(r.matches[0].matched).assertEqual('b');
      expect(r.matches[0].index).assertEqual(1);
      expect(r.matches[1].index).assertEqual(5);
    });

    it('坏正则报错；空输入/空模式报错', 0, () => {
      expect(replacePreview('abc', '(', '', '').failure.code)
        .assertEqual(RegexReplaceFailureCode.BAD_REGEX);
      expect(replacePreview('', 'a', '', '').failure.code)
        .assertEqual(RegexReplaceFailureCode.EMPTY_INPUT);
      expect(replacePreview('abc', '', '', '').failure.code)
        .assertEqual(RegexReplaceFailureCode.EMPTY_PATTERN);
    });

    it('空匹配不死循环', 0, () => {
      const r = replacePreview('abc', 'x*', 'g', '-');
      expect(r.ok).assertEqual(true);
    });
  });
}
