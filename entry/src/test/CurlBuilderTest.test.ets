import { describe, expect, it } from '@ohos/hypium';
import {
  buildHttpCommand,
  CurlFailureCode,
  normalizeUrl
} from '../main/ets/tools/curl-builder/CurlLogic';

const Q = String.fromCharCode(39);

/**
 * HTTP 命令生成的单测：**输出精确断言**（拼接顺序/转义/双输出一致）。
 */
const LF2 = String.fromCharCode(10);
export default function curlBuilderTest() {
  describe('curlBuilderTest', () => {
    it('基本 GET：scheme 补全 + 头部 -H', 0, () => {
      const r = buildHttpCommand('GET', 'api.test/v1', 'Accept: application/json', '');
      expect(r.ok).assertEqual(true);
      expect(r.curl).assertEqual('curl -X GET ' + Q + 'https://api.test/v1' + Q + ' -H ' + Q + 'Accept: application/json' + Q);
      expect(r.httpie).assertEqual('http GET https://api.test/v1 ' + Q + 'Accept' + Q + ':' + Q + 'application/json' + Q);
    });

    it('POST + body：curl 带 -d，GET 不带 body', 0, () => {
      const post = buildHttpCommand('POST', 'https://a.test', '', '{"x":1}');
      expect(post.curl.indexOf('-d') > 0).assertEqual(true);
      const get = buildHttpCommand('GET', 'https://a.test', '', '{"x":1}');
      expect(get.curl.indexOf('-d') < 0).assertEqual(true);
    });

    it('单引号转义', 0, () => {
      const r = buildHttpCommand('POST', 'https://a.test', '', 'it' + Q + 's');
      expect(r.curl.indexOf(String.fromCharCode(92)) > 0).assertEqual(true);
    });

    it('空 URL 报错；坏头报错', 0, () => {
      expect(buildHttpCommand('GET', '', '', '').failure.code).assertEqual(CurlFailureCode.EMPTY_URL);
      expect(buildHttpCommand('GET', 'https://a.test', 'no-colon-line', '').failure.code)
        .assertEqual(CurlFailureCode.BAD_HEADER);
    });

    it('normalizeUrl：有 scheme 不动，无 scheme 补 https', 0, () => {
      expect(normalizeUrl('https://a.test')).assertEqual('https://a.test');
      expect(normalizeUrl('a.test')).assertEqual('https://a.test');
    });

    it('多行头部：空行跳过，全部进入输出', 0, () => {
      const r = buildHttpCommand('GET', 'https://a.test', 'A: 1' + LF2 + 'B: 2', '');
      expect(r.curl.indexOf('-H ' + Q + 'A: 1' + Q) >= 0).assertEqual(true);
      expect(r.curl.indexOf('-H ' + Q + 'B: 2' + Q) >= 0).assertEqual(true);
    });
  });
}