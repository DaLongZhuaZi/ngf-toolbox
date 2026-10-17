import { describe, expect, it } from '@ohos/hypium';
import {
  addLineNumbers,
  LineNumStyle,
  LineNumFailureCode
} from '../main/ets/tools/line-numbers/LineNumbersLogic';

const LF = String.fromCharCode(10);

/**
 * 行号添加器的单测：三种样式、起始号、右对齐、空输入。
 */
export default function lineNumbersTest() {
  describe('lineNumbersTest', () => {
    it('点样式：前缀正确', 0, () => {
      const r = addLineNumbers('a' + LF + 'b', LineNumStyle.DOT, 1);
      expect(r.output).assertEqual('1. a' + LF + '2. b');
      expect(r.lineCount).assertEqual(2);
    });

    it('方括号样式：前缀正确', 0, () => {
      const r = addLineNumbers('a' + LF + 'b', LineNumStyle.BRACKET, 1);
      expect(r.output).assertEqual('[1] a' + LF + '[2] b');
    });

    it('冒号样式：前缀正确', 0, () => {
      const r = addLineNumbers('a' + LF + 'b', LineNumStyle.COLON, 1);
      expect(r.output).assertEqual('L1: a' + LF + 'L2: b');
    });

    it('起始号：从 10 开始', 0, () => {
      const r = addLineNumbers('a' + LF + 'b', LineNumStyle.DOT, 10);
      expect(r.output).assertEqual('10. a' + LF + '11. b');
    });
    it('右对齐：9 与 10 混排时补空格', 0, () => {
      const many: Array<string> = [];
      for (let i = 0; i < 10; i++) { many.push('x'); }
      const r = addLineNumbers(many.join(LF), LineNumStyle.DOT, 1);
      const out = r.output.split(LF);
      // 第 1 行补空格对齐 '10.'
      expect(out[0].charAt(0)).assertEqual(' ');
      expect(out[9].charAt(0)).assertEqual('1');
    });

    it('空输入报错', 0, () => {
      expect(addLineNumbers('', LineNumStyle.DOT, 1).failure.code)
        .assertEqual(LineNumFailureCode.EMPTY_INPUT);
    });
  });
}