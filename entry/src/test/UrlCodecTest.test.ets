import { describe, expect, it } from '@ohos/hypium';
import {
  decodeUrlText,
  decodeUrlTextLiteral,
  encodeUrlText,
  parseUrlQuery,
  UrlCodecFailureCode
} from '../main/ets/tools/url-codec/UrlCodec';

/**
 * URL 编解码的纯逻辑单测。
 *
 * 重点盯三类容易「看起来对」的错：
 * 1. + 号的双口径（表单=空格 / RFC 3986=字面量）——两个口径都要给，不能只给一个；
 * 2. %2B 与 + 的区别——%2B 解码后必须是字面加号，不能被「+转空格」二次改写；
 * 3. 畸形 % 序列要报错而不是静默吞掉——%E4%B8%（截断的 UTF-8）是真实输入。
 */
export default function urlCodecTest() {
  describe('urlCodecTest', () => {
    it('编码：空格成 %20，中文与符号走 encodeURIComponent 口径', 0, () => {
      expect(encodeUrlText('a b')).assertEqual('a%20b');
      expect(encodeUrlText('a+b')).assertEqual('a%2Bb');
      expect(encodeUrlText('中')).assertEqual('%E4%B8%AD');
      expect(encodeUrlText('a&b=c')).assertEqual('a%26b%3Dc');
    });

    it('解码（表单口径）：+ 是空格', 0, () => {
      expect(decodeUrlText('a+b').text).assertEqual('a b');
      expect(decodeUrlText('%E4%B8%AD%E6%96%87').text).assertEqual('中文');
    });

    it('解码（字面口径）：+ 保留为 +，%2B 同样是 +', 0, () => {
      expect(decodeUrlTextLiteral('a+b').text).assertEqual('a+b');
      expect(decodeUrlTextLiteral('a%2Bb').text).assertEqual('a+b');
      // 表单口径下 %2B 不受「+转空格」影响：先换裸 +，再解码 %2B
      expect(decodeUrlText('a%2Bb').text).assertEqual('a+b');
    });

    it('畸形 % 序列报错而不是吞掉', 0, () => {
      expect(decodeUrlText('%E4%B8%').ok).assertEqual(false);
      expect(decodeUrlText('%E4%B8%').failure.code).assertEqual(UrlCodecFailureCode.MALFORMED_ESCAPE);
      expect(decodeUrlText('%ZZ').ok).assertEqual(false);
    });

    it('空输入报 EMPTY_INPUT（编解码两个方向一致）', 0, () => {
      expect(decodeUrlText('   ').failure.code).assertEqual(UrlCodecFailureCode.EMPTY_INPUT);
    });

    it('query 拆解：键值对、无值参数、空段宽容跳过', 0, () => {
      const r1 = parseUrlQuery('a=1&b=2');
      expect(r1.ok).assertEqual(true);
      expect(r1.parts.length).assertEqual(2);
      expect(r1.parts[0].key).assertEqual('a');
      expect(r1.parts[0].value).assertEqual('1');

      const r2 = parseUrlQuery('?a&b=2');
      expect(r2.parts.length).assertEqual(2);
      expect(r2.parts[0].valueless).assertEqual(true);
      expect(r2.parts[0].value).assertEqual('');

      const r3 = parseUrlQuery('a=1&&b=2');
      expect(r3.ok).assertEqual(true);
      expect(r3.parts.length).assertEqual(2);
    });

    it('query 拆解：在「每段内」找第一个 =，值里的 %3D 与 & 编码不被误切', 0, () => {
      const r = parseUrlQuery('redirect=https%3A%2F%2Fx.test%2Fa%3Fb%3D1%26c%3D2&x=y');
      expect(r.ok).assertEqual(true);
      expect(r.parts.length).assertEqual(2);
      expect(r.parts[0].key).assertEqual('redirect');
      expect(r.parts[0].value).assertEqual('https://x.test/a?b=1&c=2');
      expect(r.parts[1].key).assertEqual('x');
    });

    it('query 拆解：键编码与 + 双口径并存', 0, () => {
      const r = parseUrlQuery('q=%E4%B8%AD%E6%96%87&time=2026-01-01T00%3A00%3A00%2B08%3A00');
      expect(r.parts[0].value).assertEqual('中文');
      // %2B 是字面加号：表单口径下也不能变成空格
      expect(r.parts[1].valuePlusLiteral).assertEqual('2026-01-01T00:00:00+08:00');
      expect(r.parts[1].value).assertEqual('2026-01-01T00:00:00+08:00');
    });

    it('query 拆解：畸形序列报错并带上第几个参数', 0, () => {
      const r = parseUrlQuery('a=1&b=%ZZ');
      expect(r.ok).assertEqual(false);
      expect(r.failure.code).assertEqual(UrlCodecFailureCode.MALFORMED_ESCAPE);
      expect(r.failure.args[0]).assertEqual('2');
    });

    it('空 query 是合法状态（空串/纯 ?）', 0, () => {
      expect(parseUrlQuery('').ok).assertEqual(true);
      expect(parseUrlQuery('').parts.length).assertEqual(0);
      expect(parseUrlQuery('?').ok).assertEqual(true);
      expect(parseUrlQuery('?').parts.length).assertEqual(0);
    });
  });
}
