import { describe, expect, it } from '@ohos/hypium';
import {
  hexDump,
  HexDumpFailureCode
} from '../main/ets/tools/hex-dump/HexDumpLogic';

/**
 * 十六进制转储的单测：**手算向量**（'A' = 0x41、'AB' = 41 42、'ABC' = 41 42 43）。
 */
export default function hexDumpTest() {
  describe('hexDumpTest', () => {
    it('单字符 A：偏移 0000 + 41 + 15 空位 + A', 0, () => {
      const r = hexDump('A');
      expect(r.ok).assertEqual(true);
      const first = r.dump.split(String.fromCharCode(10))[0];
      expect(first.indexOf('0000') === 0).assertEqual(true);
      expect(first.indexOf('41') > 0).assertEqual(true);
      expect(r.byteCount).assertEqual(1);
    });

    it('三字符 ABC：41 42 43，ASCII 预览 ABC', 0, () => {
      const r = hexDump('ABC');
      expect(r.dump.indexOf('41 42 43') >= 0).assertEqual(true);
      expect(r.dump.indexOf('ABC') >= 0).assertEqual(true);
      expect(r.byteCount).assertEqual(3);
    });

    it('17 字节产生两行（16 + 1）', 0, () => {
      const s = 'abcdefghijklmnopq';
      const r = hexDump(s);
      expect(r.dump.split(String.fromCharCode(10)).length).assertEqual(2);
      expect(r.byteCount).assertEqual(17);
    });

    it('不可打印字符显示点（0x00 → .）', 0, () => {
      const r = hexDump(String.fromCharCode(0));
      const first = r.dump.split(String.fromCharCode(10))[0];
      const parts = first.split('  ');
      const asciiCol: string = first.substring(first.length - 16);
      expect(asciiCol.charAt(0)).assertEqual('.');
    });

    it('空输入报错', 0, () => {
      expect(hexDump('').failure.code).assertEqual(HexDumpFailureCode.EMPTY_INPUT);
    });
  });
}
