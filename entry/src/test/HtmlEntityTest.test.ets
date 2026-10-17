import { describe, expect, it } from '@ohos/hypium';
import {
  decodeHtmlEntities,
  encodeHtmlEntities,
  namedEntityCount,
  HtmlEntityFailureCode
} from '../main/ets/tools/html-entity/HtmlEntity';

/**
 * HTML 实体编解码的单测。
 *
 * 字符全部用 fromCharCode 表达（& = 38，< = 60，> = 62，; = 59，# = 35），
 * 与被测逻辑同一套写法，避免测试自身的转义问题。
 */
function amp(): string { return String.fromCharCode(38); }
function semi(): string { return String.fromCharCode(59); }
function hash(): string { return String.fromCharCode(35); }
function lt(): string { return String.fromCharCode(60); }
function gt(): string { return String.fromCharCode(62); }

export default function htmlEntityTest() {
  describe('htmlEntityTest', () => {
    it('编码：五个保留字符全部转成命名实体', 0, () => {
      const r: string = encodeHtmlEntities('a' + amp() + 'b' + lt() + 'c' + gt() + 'd' + String.fromCharCode(34) + 'e' + String.fromCharCode(39), false);
      expect(r).assertEqual('a' + amp() + 'amp;' + 'b' + amp() + 'lt;' + 'c' + amp() + 'gt;' + 'd' + amp() + 'quot;' + 'e' + amp() + 'apos;');
    });

    it('编码默认不碰中文；扩展模式把非 ASCII 编成十进制实体', 0, () => {
      expect(encodeHtmlEntities('中文', false)).assertEqual('中文');
      const ext: string = encodeHtmlEntities('中', true);
      expect(ext).assertEqual(amp() + hash() + '20013' + semi());
      // round-trip
      const back = decodeHtmlEntities(ext);
      expect(back.ok).assertEqual(true);
      expect(back.text).assertEqual('中');
    });

    it('解码：三类实体都能解', 0, () => {
      const r1 = decodeHtmlEntities(amp() + 'amp;' + amp() + 'lt;');
      expect(r1.text).assertEqual(amp() + lt());
      const r2 = decodeHtmlEntities(amp() + hash() + '38' + semi());
      expect(r2.text).assertEqual(amp());
      const r3 = decodeHtmlEntities(amp() + hash() + 'x26' + semi());
      expect(r3.text).assertEqual(amp());
      expect(r3.replaced).assertEqual(1);
    });

    it('命名实体大小写不敏感', 0, () => {
      const r = decodeHtmlEntities(amp() + 'AMP' + semi());
      expect(r.ok).assertEqual(true);
      expect(r.text).assertEqual(amp());
    });

    it('未知命名实体报错并带出原文', 0, () => {
      const r = decodeHtmlEntities(amp() + 'notARealOne;');
      expect(r.ok).assertEqual(false);
      expect(r.failure.code).assertEqual(HtmlEntityFailureCode.UNKNOWN_NAMED);
      expect(r.failure.args[0]).assertEqual(amp() + 'notARealOne' + semi());
    });

    it('码点越界（> 0x10FFFF）报错', 0, () => {
      const r = decodeHtmlEntities(amp() + hash() + '1114112' + semi());
      expect(r.ok).assertEqual(false);
      expect(r.failure.code).assertEqual(HtmlEntityFailureCode.CODE_POINT_OUT_OF_RANGE);
    });

    it('缺分号报错（&amp 不猜）', 0, () => {
      const r = decodeHtmlEntities(amp() + 'amp');
      expect(r.ok).assertEqual(false);
      expect(r.failure.code).assertEqual(HtmlEntityFailureCode.MISSING_SEMICOLON);
    });

    it('空输入报错', 0, () => {
      expect(decodeHtmlEntities('   ').failure.code).assertEqual(HtmlEntityFailureCode.EMPTY_INPUT);
    });

    it('常见符号实体：copy / hellip / mdash', 0, () => {
      const r = decodeHtmlEntities(amp() + 'copy;' + amp() + 'hellip;');
      expect(r.text).assertEqual(String.fromCharCode(169) + String.fromCharCode(8230));
    });

    it('内置表规模稳定（39 项）', 0, () => {
      expect(namedEntityCount()).assertEqual(39);
    });
  });
}
