import { describe, expect, it } from '@ohos/hypium';
import {
  parseUrl,
  UrlParseFailureCode
} from '../main/ets/tools/url-parser/UrlParser';

/**
 * URL 解析器的单测：**结构断言**（每段独立断言）。
 * 重点：端口默认值、userinfo 位置、query 的 + 与 %20、fragment 隔离。
 */
export default function urlParserTest() {
  describe('urlParserTest', () => {
    it('完整 URL：scheme/userinfo/host/port/path/query/fragment 全拆', 0, () => {
      const r = parseUrl('https://user:pass@api.test:8443/v1/users?active=true&x=%2B#top');
      expect(r.ok).assertEqual(true);
      expect(r.scheme).assertEqual('https');
      expect(r.userinfo).assertEqual('user:pass');
      expect(r.host).assertEqual('api.test');
      expect(r.port).assertEqual('8443');
      expect(r.effectivePort).assertEqual('8443');
      expect(r.path).assertEqual('/v1/users');
      expect(r.query).assertEqual('active=true&x=%2B');
      expect(r.fragment).assertEqual('top');
    });

    it('默认端口：http=80, https=443', 0, () => {
      expect(parseUrl('http://a.test').effectivePort).assertEqual('80');
      expect(parseUrl('https://a.test').effectivePort).assertEqual('443');
      expect(parseUrl('ftp://a.test').effectivePort).assertEqual('');
    });

    it('query 对：+ 是空格、%2B 是字面加号', 0, () => {
      const r = parseUrl('https://a.test/?q=a+b&lit=%2B');
      expect(r.queryPairs.length).assertEqual(2);
      expect(r.queryPairs[0].key).assertEqual('q');
      expect(r.queryPairs[0].value).assertEqual('a b');
      expect(r.queryPairs[1].value).assertEqual('+');
    });

    it('fragment 里的 ? 不算 query', 0, () => {
      const r = parseUrl('https://a.test/page#section?x=1');
      expect(r.query).assertEqual('');
      expect(r.fragment).assertEqual('section?x=1');
      expect(r.queryPairs.length).assertEqual(0);
    });

    it('无 path 时 path 为空串', 0, () => {
      const r = parseUrl('https://a.test');
      expect(r.path).assertEqual('');
      expect(r.host).assertEqual('a.test');
    });

    it('userinfo 只在 host 前的 @ 生效（path 里的 @ 不算）', 0, () => {
      const r = parseUrl('https://a.test/user@name');
      expect(r.userinfo).assertEqual('');
      expect(r.host).assertEqual('a.test');
      expect(r.path).assertEqual('/user@name');
    });

    it('非法端口（超 65535、非数字）报错', 0, () => {
      expect(parseUrl('http://a.test:99999').failure.code)
        .assertEqual(UrlParseFailureCode.NO_HOST);
      expect(parseUrl('http://a.test:abc').failure.code)
        .assertEqual(UrlParseFailureCode.NO_HOST);
    });

    it('无 scheme、空输入、缺 host 报错', 0, () => {
      expect(parseUrl('a.test/x').failure.code).assertEqual(UrlParseFailureCode.NO_SCHEME);
      expect(parseUrl('').failure.code).assertEqual(UrlParseFailureCode.EMPTY_INPUT);
      expect(parseUrl('https://').failure.code).assertEqual(UrlParseFailureCode.NO_HOST);
    });

    it('大写 scheme 归一小写', 0, () => {
      expect(parseUrl('HTTPS://A.TEST').scheme).assertEqual('https');
    });
  });
}
