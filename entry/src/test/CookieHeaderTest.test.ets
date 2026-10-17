import { describe, expect, it } from '@ohos/hypium';
import {
  parseCookieHeader,
  parseSetCookie,
  CookieFailureCode
} from '../main/ets/tools/cookie-header/CookieHeaderLogic';

/**
 * Cookie 头解析的单测：请求侧拆对、响应侧属性表。
 */
export default function cookieHeaderTest() {
  describe('cookieHeaderTest', () => {
    it('请求侧：两个键值对', 0, () => {
      const r = parseCookieHeader('sid=abc123; theme=dark');
      expect(r.ok).assertEqual(true);
      expect(r.pairs.length).assertEqual(2);
      expect(r.pairs[0].name).assertEqual('sid');
      expect(r.pairs[0].value).assertEqual('abc123');
      expect(r.pairs[1].value).assertEqual('dark');
    });

    it('请求侧：值里有等号（base64 形态）只切第一个', 0, () => {
      const r = parseCookieHeader('token=AbC=ef;');
      expect(r.pairs.length).assertEqual(1);
      expect(r.pairs[0].value).assertEqual('AbC=ef');
    });

    it('请求侧：无等号的段保留名字空值', 0, () => {
      const r = parseCookieHeader('flag');
      expect(r.pairs[0].name).assertEqual('flag');
      expect(r.pairs[0].value).assertEqual('');
    });

    it('响应侧：属性全表', 0, () => {
      const r = parseSetCookie('sid=abc; Path=/; Domain=x.test; Max-Age=3600; Secure; HttpOnly; SameSite=Lax');
      expect(r.name).assertEqual('sid');
      expect(r.value).assertEqual('abc');
      expect(r.attrs.get('path')).assertEqual('/');
      expect(r.attrs.get('domain')).assertEqual('x.test');
      expect(r.attrs.get('max-age')).assertEqual('3600');
      expect(r.attrs.get('secure')).assertEqual('');
      expect(r.attrs.get('httponly')).assertEqual('');
      expect(r.attrs.get('samesite')).assertEqual('Lax');
    });

    it('响应侧：空输入报错', 0, () => {
      expect(parseSetCookie('').failure.code).assertEqual(CookieFailureCode.EMPTY_INPUT);
      expect(parseCookieHeader('').failure.code).assertEqual(CookieFailureCode.EMPTY_INPUT);
    });
  });
}
