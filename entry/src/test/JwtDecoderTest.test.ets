import { describe, expect, it } from '@ohos/hypium';
import {
  Base64UrlFailure,
  decodeBase64Url,
  decodeJwt,
  decodeUtf8,
  describeRelative,
  formatTimestampSeconds,
  JWT_MAX_TOKEN_LENGTH,
  JwtDecodeFailureCode,
  JwtRelativeCode,
  JwtTimeFailure,
  NGFJwtDecodeResult,
  TimeSpanUnit
} from '../main/ets/tools/jwt-decoder/JwtDecoder';
import { NGFJsonFailure } from '../main/ets/tools/jwt-decoder/JwtJson';
import { parseJson, NGFJsonParseResult } from '../main/ets/tools/jwt-decoder/JwtJson';

/**
 * JWT 解码的纯逻辑单测。
 *
 * 测试里的 token 都是**真实构造**出来的（用参考实现按 RFC 7519 生成 Base64URL 片段），
 * 不是随手编的字符串——否则「解出来对不对」本身就没有对照物。
 * 时间断言一律传入固定的 now，绝不依赖运行时的当前时间，否则用例会隔一段时间就红。
 */
export default function jwtDecoderTest() {
  describe('jwtDecoderTest', () => {
    /** 固定的"现在"：2026-01-01 00:00:00 UTC 之前，用来判断样例 token 的过期状态 */
    const now: number = 1767225599000;
    const standardToken: string = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      + '.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IuW8oOS4iSIsImFkbWluIjp0cnVlLCJleHAiOjE3NjcyMjU2MDAs'
      + 'ImlhdCI6MTczNTY4OTYwMCwibmJmIjoxNzM1Njg5NjAwfQ'
      + '.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';

    it('标准三段 JWT 能解出 Header 与 Payload(防分段/解码基调错)', 0, () => {
      const result: NGFJwtDecodeResult = decodeJwt(standardToken, now);
      expect(result.ok).assertTrue();
      expect(result.segmentCount).assertEqual(3);
      expect(result.algorithm).assertEqual('HS256');
      expect(result.tokenType).assertEqual('JWT');
      expect(result.headerJson).assertContain('"alg": "HS256"');
      expect(result.payloadJson).assertContain('"sub": "1234567890"');
      expect(result.payloadJson).assertContain('张三');
      expect(result.payloadJson).assertContain('"admin": true');
    });

    it('签名段原样展示且不参与解码(防误以为验过签)', 0, () => {
      const result: NGFJwtDecodeResult = decodeJwt(standardToken, now);
      expect(result.signature).assertEqual('SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c');
      expect(result.headerRaw).assertEqual('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9');
    });

    it('exp / nbf / iat 按固定顺序转成人话(防声明乱序或漏解)', 0, () => {
      const result: NGFJwtDecodeResult = decodeJwt(standardToken, now);
      expect(result.claims.length).assertEqual(3);
      expect(result.claims[0].key).assertEqual('exp');
      expect(result.claims[1].key).assertEqual('nbf');
      expect(result.claims[2].key).assertEqual('iat');
      expect(result.claims[0].rawValue).assertEqual('1767225600');
      // 可读时间不再自带「（本地时区）」——那句是文案，归 UI 层
      expect(result.claims[0].dateTimeText.length > 0).assertTrue();
      expect(result.claims[0].timeFailure).assertEqual(JwtTimeFailure.NONE);
      expect(result.claims[0].relative.code).assertEqual(JwtRelativeCode.FUTURE);
    });

    it('exp 已过必须判过期、未到必须判有效(防比较方向写反)', 0, () => {
      const beforeExpiry: NGFJwtDecodeResult = decodeJwt(standardToken, 1767225599000);
      expect(beforeExpiry.hasExpiration).assertTrue();
      expect(beforeExpiry.expired).assertFalse();
      const afterExpiry: NGFJwtDecodeResult = decodeJwt(standardToken, 1767225601000);
      expect(afterExpiry.expired).assertTrue();
      expect(afterExpiry.claims[0].relative.code).assertEqual(JwtRelativeCode.PAST);
    });

    it('exp 为 0 必须判过期(防把 0 当假值跳过判断)', 0, () => {
      const token: string = 'eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjB9.sig';
      const result: NGFJwtDecodeResult = decodeJwt(token, now);
      expect(result.ok).assertTrue();
      expect(result.hasExpiration).assertTrue();
      expect(result.expired).assertTrue();
      expect(result.claims.length).assertEqual(1);
      expect(result.claims[0].rawValue).assertEqual('0');
    });

    it('缺少 exp 时不能报"已过期"，只能说明没有过期时间', 0, () => {
      const token: string = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4In0.sig';
      const result: NGFJwtDecodeResult = decodeJwt(token, now);
      expect(result.ok).assertTrue();
      expect(result.hasExpiration).assertFalse();
      expect(result.expired).assertFalse();
      expect(result.claims.length).assertEqual(0);
    });

    it('nbf 在未来时给出"还有"而不是"已过去"', 0, () => {
      const token: string = 'eyJhbGciOiJIUzI1NiJ9.eyJuYmYiOjQxMDI0NDQ4MDAsImlhdCI6NDEwMjQ0NDgwMH0.sig';
      const result: NGFJwtDecodeResult = decodeJwt(token, now);
      expect(result.ok).assertTrue();
      expect(result.claims[0].key).assertEqual('nbf');
      // isPast 已并入 relative.code：断言方向而不是一个单独的布尔量，
      // 免得「方向」与「布尔量」两处表达同一件事、迟早有一天不一致。
      expect(result.claims[0].relative.code).assertEqual(JwtRelativeCode.FUTURE);
      expect(result.claims[0].relative.value > 0).assertTrue();
    });

    it('段数不是 3 时必须报错并说清当前段数', 0, () => {
      const tooFew: NGFJwtDecodeResult = decodeJwt('abc.def', now);
      expect(tooFew.ok).assertFalse();
      expect(tooFew.failure.code).assertEqual(JwtDecodeFailureCode.WRONG_SEGMENTS);
      expect(tooFew.failure.args[0]).assertEqual('2');
      const one: NGFJwtDecodeResult = decodeJwt('abc', now);
      expect(one.ok).assertFalse();
      expect(one.segmentCount).assertEqual(1);
    });

    it('5 段的 JWE 给出专门提示而不是当成坏 token', 0, () => {
      const result: NGFJwtDecodeResult = decodeJwt('a.b.c.d.e', now);
      expect(result.ok).assertFalse();
      expect(result.segmentCount).assertEqual(5);
      expect(result.failure.code).assertEqual(JwtDecodeFailureCode.JWE);
    });

    it('Base64URL 的 - _ 变体与缺失 padding 都要能解(防按标准 Base64 解)', 0, () => {
      const dashAndUnderscore: string = 'eyJhIjoiw7_Dvj9-IiwiZXhwIjoxfQ';
      const decoded = decodeBase64Url(dashAndUnderscore);
      expect(decoded.ok).assertTrue();
      expect(decodeUtf8(decoded.bytes)).assertEqual('{"a":"\u00ff\u00fe?~","exp":1}');
      const segments: string[] = dashAndUnderscore.split('.');
      expect(segments.length).assertEqual(1);
      const result: NGFJwtDecodeResult = decodeJwt(
        'eyJhbGciOiJIUzI1NiJ9.' + dashAndUnderscore + '.sig', now);
      expect(result.ok).assertTrue();
      expect(result.claims[0].rawValue).assertEqual('1');
    });

    it('带 = 补齐的 Base64URL 也要接受(用户可能从别处粘来)', 0, () => {
      const decoded = decodeBase64Url('eyJhIjoxfQ==');
      expect(decoded.ok).assertTrue();
      expect(decodeUtf8(decoded.bytes)).assertEqual('{"a":1}');
    });

    it('非法 Base64URL 字符必须报错而不是解出乱码', 0, () => {
      const decoded = decodeBase64Url('eyJhIjoi$%^&IjoxfQ');
      expect(decoded.ok).assertFalse();
      // decodeBase64Url 返回的是 Base64UrlFailure 本身（JWT 那层才是两层结构）
      expect(decoded.failure).assertEqual(Base64UrlFailure.BAD_CHAR);
    });

    it('Base64URL 长度余 1 必须报错(防解出半截数据)', 0, () => {
      const decoded = decodeBase64Url('eyJhIjoxf');
      expect(decoded.ok).assertFalse();
      // decodeBase64Url 返回的就是 Base64UrlFailure 本身（不是 JWT 那种两层结构）
      expect(decoded.failure).assertEqual(Base64UrlFailure.LENGTH_MOD1);
    });

    it('Payload 不是 JSON 时报错并给出行列号', 0, () => {
      const result: NGFJwtDecodeResult = decodeJwt('eyJhbGciOiJIUzI1NiJ9.bm90IGpzb24gYXQgYWxs.sig', now);
      expect(result.ok).assertFalse();
      // 失败是两层结构：外层说「哪一段、哪一类」，内层带 JSON 的具体原因与位置
      expect(result.failure.code).assertEqual(JwtDecodeFailureCode.PAYLOAD_JSON);
      expect(result.failure.line).assertEqual(1);
      expect(result.failure.column).assertEqual(1);
    });

    it('Header 不是 JSON 时报错并指明是 Header', 0, () => {
      const result: NGFJwtDecodeResult = decodeJwt('bm90IGpzb24.sig.sig', now);
      expect(result.ok).assertFalse();
      expect(result.failure.code).assertEqual(JwtDecodeFailureCode.HEADER_JSON);
    });

    it('空输入与超长输入都要给出明确提示', 0, () => {
      const empty: NGFJwtDecodeResult = decodeJwt('   ', now);
      expect(empty.ok).assertFalse();
      expect(empty.failure.code).assertEqual(JwtDecodeFailureCode.EMPTY);
      const tooLong: NGFJwtDecodeResult = decodeJwt('a'.repeat(JWT_MAX_TOKEN_LENGTH + 1), now);
      expect(tooLong.ok).assertFalse();
      expect(tooLong.failure.code).assertEqual(JwtDecodeFailureCode.TOO_LONG);
      expect(tooLong.failure.args[0]).assertEqual(String(JWT_MAX_TOKEN_LENGTH));
    });

    it('超出 2^53 的数值必须原样保留(防 JSON 美化时丢精度)', 0, () => {
      const token: string = 'eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjkwMDcxOTkyNTQ3NDA5OTN9.sig';
      const result: NGFJwtDecodeResult = decodeJwt(token, now);
      expect(result.ok).assertTrue();
      expect(result.payloadJson).assertContain('9007199254740993');
      expect(result.claims[0].rawValue).assertEqual('9007199254740993');
    });

    it('中文与 emoji 载荷按 UTF-8 正确还原(防代理对丢一半)', 0, () => {
      const token: string = 'eyJhbGciOiJIUzI1NiJ9.eyJtc2ciOiLkvaDlpb3wn5iAIiwiZXhwIjoxNzY3MjI1NjAwfQ.sig';
      const result: NGFJwtDecodeResult = decodeJwt(token, now);
      expect(result.ok).assertTrue();
      expect(result.payloadJson).assertContain('你好😀');
    });

    it('非法 UTF-8 字节替换为 U+FFFD 而不是抛异常', 0, () => {
      const broken: Uint8Array = new Uint8Array(4);
      broken[0] = 0x41;
      broken[1] = 0xe4;
      broken[2] = 0xbd;
      broken[3] = 0x41;
      const decoded: string = decodeUtf8(broken);
      expect(decoded.charAt(0)).assertEqual('A');
      expect(decoded.indexOf('A', 1) > 0).assertTrue();
    });

    it('时间戳格式化：非数字与超范围都要给出原因', 0, () => {
      expect(formatTimestampSeconds('abc').failure).assertEqual(JwtTimeFailure.NOT_A_NUMBER);
      expect(formatTimestampSeconds('1e30').failure).assertEqual(JwtTimeFailure.OUT_OF_RANGE);
      expect(formatTimestampSeconds('1767225600').dateTimeText).assertEqual('2026-01-01 08:00:00');
    });

    it('相对时间描述覆盖秒/分/时/天四档', 0, () => {
      expect(describeRelative('1767225599', 1767225600000).unit).assertEqual(TimeSpanUnit.SECONDS);
      expect(describeRelative('1767225599', 1767225600000).code).assertEqual(JwtRelativeCode.PAST);
      expect(describeRelative('1767225300', 1767225600000).unit).assertEqual(TimeSpanUnit.MINUTES);
      expect(describeRelative('1767222000', 1767225600000).unit).assertEqual(TimeSpanUnit.HOURS);
      expect(describeRelative('1767139200', 1767225600000).unit).assertEqual(TimeSpanUnit.DAYS);
    });

    it('JSON 解析器能定位尾逗号这类错误(防错误位置指错)', 0, () => {
      const parsed: NGFJsonParseResult = parseJson('{"a":1,}');
      expect(parsed.ok).assertFalse();
      expect(parsed.position.line).assertEqual(1);
      expect(parsed.position.column).assertEqual(8);
    });
  });
}