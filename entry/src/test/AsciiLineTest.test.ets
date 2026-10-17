import { describe, expect, it } from '@ohos/hypium';
import {
  buildAscii,
  AsciiFailureCode
} from '../main/ets/tools/ascii-line/AsciiLineLogic';

/**
 * ASCII 分隔线的单测：**逐字符断言**（长度/首尾/居中）+ 错误路径。
 */
export default function asciiLineTest() {
  describe('asciiLineTest', () => {
    it('line：宽度正确、全等号、带 // 前缀', 0, () => {
      const r = buildAscii('eq', 'line', 'c', '40', '');
      const line = r.output;
      expect(line.length).assertEqual(43);
      for (let i = 3; i < line.length; i++) {
        expect(line.charAt(i)).assertEqual('=');
      }
    });

    it('banner：文本居中夹在横线之间', 0, () => {
      const r = buildAscii('eq', 'banner', 'c', '30', 'HELLO');
      const parts = r.output.split(String.fromCharCode(10));
      expect(parts.length).assertEqual(3);
      // 中间行含 HELLO 且两侧填充后总宽 30
      const mid = parts[1].substring(3);
      expect(mid.length).assertEqual(30);
      expect(mid.indexOf('HELLO') > 0).assertEqual(true);
    });

    it('box：加号边框与竖线', 0, () => {
      const r = buildAscii('dash', 'box', 'hash', '40', 'TITLE');
      const parts = r.output.split(String.fromCharCode(10));
      expect(parts.length).assertEqual(3);
      expect(parts[0].charAt(2)).assertEqual('+');
      expect(parts[1].indexOf('| ') === 2 && parts[1].indexOf('TITLE') > 2).assertEqual(true);
      expect(parts[2].charAt(2)).assertEqual('+');
    });

    it('hash 前缀：井号 + 空格', 0, () => {
      const r = buildAscii('eq', 'line', 'hash', '20', '');
      expect(r.output.charAt(0)).assertEqual('#');
      expect(r.output.charAt(1)).assertEqual(' ');
    });

    it('sql 前缀：双横线 + 空格', 0, () => {
      const r = buildAscii('eq', 'line', 'sql', '20', '');
      expect(r.output.charAt(0)).assertEqual('-');
      expect(r.output.charAt(1)).assertEqual('-');
      expect(r.output.charAt(2)).assertEqual(' ');
    });

    it('宽度越界与非法输入报错', 0, () => {
      expect(buildAscii('eq', 'line', 'c', '9', '').failure.code)
        .assertEqual(AsciiFailureCode.WIDTH_OUT_OF_RANGE);
      expect(buildAscii('eq', 'line', 'c', '121', '').failure.code)
        .assertEqual(AsciiFailureCode.WIDTH_OUT_OF_RANGE);
      expect(buildAscii('eq', 'line', 'c', 'abc', '').failure.code)
        .assertEqual(AsciiFailureCode.WIDTH_OUT_OF_RANGE);
    });

    it('banner/box 空文本报错', 0, () => {
      expect(buildAscii('eq', 'banner', 'c', '30', '   ').failure.code)
        .assertEqual(AsciiFailureCode.EMPTY_TEXT);
      expect(buildAscii('eq', 'box', 'c', '30', '').failure.code)
        .assertEqual(AsciiFailureCode.EMPTY_TEXT);
    });
  });
}
