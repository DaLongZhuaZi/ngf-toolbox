import { describe, expect, it } from '@ohos/hypium';
import {
  minifyCode,
  MinifyFailureCode
} from '../main/ets/tools/code-minify/CodeMinifyLogic';

const LF = String.fromCharCode(10);
const SL = String.fromCharCode(47);
const STAR = String.fromCharCode(42);
const Q = String.fromCharCode(39);

/**
 * 代码压缩的单测：注释剥离、字符串保护、空白压缩、未闭合块报错。
 */
export default function codeMinifyTest() {
  describe('codeMinifyTest', () => {
    it('行注释剥离', 0, () => {
      const r = minifyCode('let a = 1 ' + SL + SL + ' note');
      expect(r.output).assertEqual('let a = 1');
    });

    it('块注释剥离（跨行）', 0, () => {
      const r = minifyCode('a' + LF + SL + STAR + ' note ' + STAR + SL + LF + 'b');
      expect(r.output).assertEqual('a b');
    });

    it('字符串内的注释符号不剥离', 0, () => {
      const r = minifyCode('u = "http//x"');
      expect(r.output.indexOf('http//x') >= 0).assertEqual(true);
    });

    it('连续空白压成单空格', 0, () => {
      const r = minifyCode('a    b' + LF + LF + 'c');
      expect(r.output).assertEqual('a b c');
    });

    it('体积统计', 0, () => {
      const r = minifyCode('ab  c');
      expect(r.originalLength).assertEqual(5);
      expect(r.minifiedLength).assertEqual(4);
    });

    it('未闭合块注释报错', 0, () => {
      const r = minifyCode('a' + LF + SL + STAR + ' never closed');
      expect(r.failure.code).assertEqual(MinifyFailureCode.UNCLOSED_BLOCK);
    });

    it('空输入报错', 0, () => {
      expect(minifyCode('  ').failure.code).assertEqual(MinifyFailureCode.EMPTY_INPUT);
    });
  });
}