import { describe, expect, it } from '@ohos/hypium';
import {
  generateLorem,
  LoremFailureCode,
  LoremLanguage
} from '../main/ets/tools/lorem-ipsum/LoremIpsum';

/**
 * 占位文本生成的单测。
 *
 * 核心断言是「确定性」：同一种子必须产出完全相同的文本——这是用
 * 种子随机而不是 Math.random 的全部理由。
 */
export default function loremIpsumTest() {
  describe('loremIpsumTest', () => {
    it('确定性：同一种子两次生成完全一致', 0, () => {
      const a = generateLorem(2, 3, 42, LoremLanguage.LATIN);
      const b = generateLorem(2, 3, 42, LoremLanguage.LATIN);
      expect(a.paragraphs.join('|')).assertEqual(b.paragraphs.join('|'));
      expect(a.words).assertEqual(b.words);
    });

    it('不同种子产出不同文本（词表随机性存在）', 0, () => {
      const a = generateLorem(1, 3, 42, LoremLanguage.LATIN);
      const b = generateLorem(1, 3, 43, LoremLanguage.LATIN);
      expect(a.paragraphs.join('|') !== b.paragraphs.join('|')).assertEqual(true);
    });

    it('段落数与句数结构正确', 0, () => {
      const r = generateLorem(3, 2, 7, LoremLanguage.LATIN);
      expect(r.paragraphs.length).assertEqual(3);
      // 每段 2 句 → 2 个句号
      const first: string = r.paragraphs[0];
      let dots: number = 0;
      for (let i = 0; i < first.length; i++) {
        if (first.charAt(i) === String.fromCharCode(46)) {
          dots++;
        }
      }
      expect(dots).assertEqual(2);
    });

    it('拉丁文首字母大写、句号收尾', 0, () => {
      const r = generateLorem(1, 1, 9, LoremLanguage.LATIN);
      const p: string = r.paragraphs[0];
      expect(p.charAt(0) === p.charAt(0).toUpperCase()).assertEqual(true);
      expect(p.charAt(p.length - 1)).assertEqual(String.fromCharCode(46));
    });

    it('中文词表：逗号分隔、句号收尾', 0, () => {
      const r = generateLorem(1, 2, 5, LoremLanguage.CHINESE);
      const p: string = r.paragraphs[0];
      expect(p.charAt(p.length - 1)).assertEqual(String.fromCharCode(65294));
      expect(p.indexOf(String.fromCharCode(65292)) > 0).assertEqual(true);
    });

    it('词数统计与词表随机范围一致（每句 6-14 词）', 0, () => {
      const r = generateLorem(2, 2, 11, LoremLanguage.LATIN);
      // 4 句 × 6..14 词 = 24..56
      expect(r.words >= 24 && r.words <= 56).assertEqual(true);
    });

    it('参数越界报错（0 段、21 段、0 句）', 0, () => {
      expect(generateLorem(0, 3, 1, LoremLanguage.LATIN).failure.code)
        .assertEqual(LoremFailureCode.COUNT_OUT_OF_RANGE);
      expect(generateLorem(21, 3, 1, LoremLanguage.LATIN).failure.code)
        .assertEqual(LoremFailureCode.COUNT_OUT_OF_RANGE);
      expect(generateLorem(1, 0, 1, LoremLanguage.LATIN).failure.code)
        .assertEqual(LoremFailureCode.COUNT_OUT_OF_RANGE);
    });

    it('上下界恰好合法（1 与 20）', 0, () => {
      expect(generateLorem(1, 1, 1, LoremLanguage.LATIN).ok).assertEqual(true);
      expect(generateLorem(20, 20, 1, LoremLanguage.LATIN).ok).assertEqual(true);
    });
  });
}
