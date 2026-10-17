import { describe, expect, it } from '@ohos/hypium';
import {
  wrapText,
  WrapFailureCode
} from '../main/ets/tools/word-wrap/WordWrapLogic';

/**
 * 自动换行的单测：贪心装行/超长词断行/显式换行保留/宽度校验。
 */
export default function wordWrapTest() {
  describe('wordWrapTest', () => {
    it('基本装行：不超宽单行', 0, () => {
      const r = wrapText('hello world', '40');
      expect(r.ok).assertEqual(true);
      expect(r.lineCount).assertEqual(1);
      expect(r.output).assertEqual('hello world');
    });

    it('贪心装行：一行装不下就换', 0, () => {
      const r = wrapText('aa bb cc dd', '10');
      const linesArr = r.output.split(String.fromCharCode(10));
      // 'aa bb' 5 字符可加 ' cc' = 8 ✓；'dd' 换行
      expect(linesArr[0]).assertEqual('aa bb cc');
      expect(linesArr[1]).assertEqual('dd');
    });

    it('超长词强制断到行宽', 0, () => {
      const r = wrapText('abcdefghijklm', '10');
      const linesArr = r.output.split(String.fromCharCode(10));
      expect(linesArr[0]).assertEqual('abcdefghij');
      expect(linesArr[1]).assertEqual('klm');
    });

    it('显式换行保留为空行边界', 0, () => {
      const r = wrapText('para one' + String.fromCharCode(10) + 'para two', '40');
      expect(r.lineCount).assertEqual(2);
      expect(r.output.indexOf('para one') === 0).assertEqual(true);
    });

    it('宽度越界报错；空输入报错', 0, () => {
      expect(wrapText('x', '9').failure.code).assertEqual(WrapFailureCode.WIDTH_OUT_OF_RANGE);
      expect(wrapText('x', '201').failure.code).assertEqual(WrapFailureCode.WIDTH_OUT_OF_RANGE);
      expect(wrapText('x', 'abc').failure.code).assertEqual(WrapFailureCode.WIDTH_OUT_OF_RANGE);
      expect(wrapText('', '40').failure.code).assertEqual(WrapFailureCode.EMPTY_INPUT);
    });
  });
}
